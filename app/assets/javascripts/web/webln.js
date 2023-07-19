console.log("webln.js")
function ln() {
    $(document).on('click', '[data-behavior~=toggle_lightning]', function (event) {
        console.log("heressss");
        console.log("event:", event);

        address = $(this).data('ln')
        amount = 1111
        message = "hello"

        try {
            if (typeof window.webln !== 'undefined') {

                keysend(address, amount, message)
            }
            else {
                return alert("No WebLN available.");
            }
        } catch (error) {
            console.log(error);
        }
        event.preventDefault();
        return;
    });
}

ln()


async function keysend(address, amount, message) {
    try {
        await window.webln.enable();

        // Data from https://podcastindex.org/podcast/920666
        // const boost = {
        //     action: "boost",
        //     value_msat: 1000,
        //     value_msat_total: 1000,
        //     app_name: "⚡ WebLN Demo",
        //     app_version: "1.0",
        //     feedID: "https://feeds.podcastindex.org/pc20.xml",
        //     podcast: "Podcasting 2.0",
        //     episode: "Episode 104: A New Dump",
        //     ts: 21,
        //     name: "⚡ WebLN Demo",
        //     sender_name: "Sathoshi Nakamoto",
        //     message: "Go podcasting!"
        // };

        const result = await webln.keysend({
            destination:
                address,
            amount: amount,
            customRecords: {
                34349334: message
                // 7629169: JSON.stringify(boost)
            }
        });

        showResult(result);
        celebrate();
    } catch (error) {
        throw error;
        alert("User denied permission or cancelled.");
    }
}
