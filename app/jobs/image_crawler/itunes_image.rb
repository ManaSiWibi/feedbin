module ImageCrawler
  class ItunesImage
    include Sidekiq::Worker
    sidekiq_options retry: false

    def perform(public_id, image = nil)
      public_id = public_id.split("-").first
      @entry = Entry.find_by_public_id(public_id)
      @image = image

      if @image
        receive
      else
        schedule
      end
    rescue ActiveRecord::RecordNotFound
    end

    def schedule
      image = Image.new({
        id: "#{@entry.public_id}-itunes",
        preset_name: "podcast",
        image_urls: [@entry.rebase_url(@entry.data["itunes_image"])]
      })
      Pipeline::Find.perform_async(image.to_h)
    end

    def receive
      @entry.update(media_image: @image["processed_url"])
    end
  end
end