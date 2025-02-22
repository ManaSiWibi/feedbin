module FeedCrawler
  class Downloader
    include Sidekiq::Worker
    include SidekiqHelper

    sidekiq_options queue: :crawl, retry: false, backtrace: false

    attr_accessor :critical

    def perform(feed_id, feed_url, subscribers, crawl_data = {})
      @feed_id     = feed_id
      @feed_url    = feed_url
      @subscribers = subscribers
      @crawl_data  = CrawlData.new(crawl_data)
      @parsing     = false

      download
    ensure
      persist_crawl_data unless @parsing
    end

    def download
      @crawl_data.log_download

      @response = begin
        request
      rescue Feedkit::ZlibError
        request(auto_inflate: false)
      end

      @crawl_data.download_success(@feed_id)

      modified = !@response.not_modified?(@crawl_data.download_fingerprint)
      Sidekiq.logger.info "Downloaded modified=#{modified} http_status=\"#{@response.status}\" url=#{@feed_url} ignore_http_caching=#{@crawl_data.ignore_http_caching?}"

      parse if modified
    rescue Feedkit::Error => exception
      @crawl_data.download_error(exception)
      Sidekiq.logger.info "Feedkit::Error: attempts=#{@crawl_data.error_count} exception=#{exception.inspect} id=#{@feed_id} url=#{@feed_url}"
    end

    def request(auto_inflate: true)
      parsed_url = Feedkit::BasicAuth.parse(@feed_url)
      url = @crawl_data.redirected_to ? @crawl_data.redirected_to : parsed_url.url
      Sidekiq.logger.info "Redirect: from=#{@feed_url} to=#{@crawl_data.redirected_to} id=#{@feed_id}" if @crawl_data.redirected_to
      Feedkit::Request.download(url,
        on_redirect:   on_redirect,
        username:      parsed_url.username,
        password:      parsed_url.password,
        last_modified: ignore_http_caching? ? nil : @crawl_data.last_modified,
        etag:          ignore_http_caching? ? nil : @crawl_data.etag,
        auto_inflate:  auto_inflate,
        user_agent:    "Feedbin feed-id:#{@feed_id} - #{@subscribers} subscribers"
      )
    end

    def on_redirect
      proc do |from, to|
        @crawl_data.redirects.push Redirect.new(@feed_id, status: from.status.code, from: from.uri.to_s, to: to.uri.to_s)
      end
    end

    def parse
      @parsing = true
      @response.persist!
      @crawl_data.save(@response)
      job_class = critical ? ParserCritical : Parser
      job_id = job_class.perform_async(@feed_id, @response.path, @response.encoding.to_s, @crawl_data.to_h)
      Sidekiq.logger.info "Parse enqueued job_id=#{job_id} path=#{@response.path}"
    end

    def persist_crawl_data
      add_to_queue(PersistCrawlData::SET_NAME, {
        id: @feed_id,
        crawl_data: @crawl_data.to_h
      }.to_json)
    end

    def ignore_http_caching?
      critical || @crawl_data.ignore_http_caching?
    end
  end
end