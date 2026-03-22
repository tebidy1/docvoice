// Full end-to-end test: connect, authenticate, see ALL server messages
const WebSocket = require('ws');
const common = require("oci-common");
const { AIServiceSpeechClient } = require("oci-aispeech");
const fs = require('fs');

async function main() {
    // Get token first
    const provider = new common.SimpleAuthenticationDetailsProvider(
        "ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a",
        "ocid1.user.oc1..aaaaaaaa3ykq2ykgaixlhze3yip5m3fxrsbkghnzecezym7c7neqk57fupdq",
        "a6:24:f0:9f:9a:f0:77:18:c5:85:2d:03:90:02:6d:c2",
        null,
        `-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC9aeoZKxpjh42c
Gy5DFMUe/Qu9zn5e+jI2uFZ28liFl+K5vok6dUW/pG0H3htbNH03pdo2419nBZ5W
6or6vFf7lnhHY8eTsZ8ZVXP7UG3yHV5hyG7e4iWCEQgOcprjjWDY9v2Rg5NIRi8V
36FAvcIgUXLKCHUTIuq6RSKKicbj/QsZsiEBdA6ZB20agIMwjhmMNeQuBG6R2JDe
WLg6kx6vUhzxqV0ULIBuRpSaUmEZ1JAzOHMKLhzZgEj423ga2Z1hRAjySdznNuoH
fKGYnDcq1QN8/vcdslDKUq51WcAWI/8kFrMULqwEb6TQz1iggSPTSzaJVaTT7eN8
jzC8b01VAgMBAAECggEAQeJxd0ey6iPgcghSUysKVfkW+HK3KjpE9Ruxl7Y8bFuk
lY9dFGRuWnbLJg1v3o2ncI/UE3uLV75wkTMMHKMex3hTZiGi7hC+koVSznvvgmQM
zF53kjd/bHqYHs5mafhnU5C2KsNlm6IuBqG+6VIYED3Ee9ntPzbKBvi9Rwsdj3d/
wKzuyM/QurCaf2rbNgEK3z8YXqYKywo0Vnfg1owcPVK8Wn4dES6xeOB0y+1Hmx6P
zwsYxpl5BXQmk1Pf1RK13FK564FMe6MhvBkRnPariW6/BJPBEOcMfZIET+tHljdM
i7FVEgzQh6v+YqNMxTbSXrrYOjeprWClN0Q1upWTkQKBgQDqqHhZI9jqOJhAw2Hg
HlKlIWBt5qogBIPkWj6X7JbA9/TCWJMp8LR3hXYZyAtdOpwrURxZ3JMPDY0ucNH3
oAc23y6yqyQypFxlneNHT/TsA54mw55Ksdz+VcFUm+3+oVN+Ob6HN7K8ugs9QXIi
9hUrTllGdSBmA7gc9bJMrD9kEwKBgQDOpAXQbQHEcassVw8+qj094YkloKCAOLwh
y4XOv08IZZOZP3F7g0lJu+rfwLC3rtEieSTFHQzARssI1rWwtqCBj5kEiwe/lnRO
91Xohevhi3NR1q3q8VWwMl9J7QK85w8XXUYmV9BPjI3Ave1o9XFpKWJW+qZPgw5Z
9K04KtUl9wKBgQDo9ujEVrp7jkRZx5/cCT6zgjdh5Kbxsoneo1mRKulgGst8RsOT
18zS/EULw3bEz/NLbfNfo4S8ZQ/NE2ThGpcO+vQ5nX8KZ/LzT5Tcr5zQ06anhX4Z
Wgu01R5jCYt2SGPD5UAqrjlc9LdD0T2nR/gsTlSDhrTrkrWuyp6BUGB+0QKBgBnt
bKlVNBaQ6JhcqBYFyD9ecBXfjKPp+nkHD1f8mw8Dp7xfwH5t36E3yeWfSM0TSzxX
FO0CkxoBB/Ko9g0hLQx0lw+B3kwEtb0+vXG6c/lNxP9sv0+uTkEYYOpmqaRIHZWh
525iMEn66cJYUlSMD1nRjnw5YOqzF/bjg2R7w1jLAoGBAIN+zY0VUwMoPSrD84lP
PX/UnDv9wjrl95oGxuahSW3LfrrLXGdeN4KAL2IFMQLhghu7O3G72DHM3LboUWQm
OONRokqHJyqd1n1fNXCCk8wUJJSAVzv3atnDtxP1Vs03yhwL6OkBnr+jyvRT/VSf
cQBOFhw1ZkYvxx4A6HSNxyae
-----END PRIVATE KEY-----`
    );

    // Get token
    const speechClient = new AIServiceSpeechClient({ authenticationDetailsProvider: provider });
    speechClient.region = common.Region.ME_RIYADH_1;
    console.log("1. Getting token...");
    const tokenResp = await speechClient.createRealtimeSessionToken({
        createRealtimeSessionTokenDetails: {
            compartmentId: "ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a"
        }
    });
    const token = tokenResp.realtimeSessionToken.token;
    console.log("   Token OK");

    // Connect WebSocket (WHISPER Arabic)
    const wsUrl = 'wss://realtime.aiservice.me-riyadh-1.oci.oraclecloud.com/ws/transcribe/stream?isAckEnabled=false&encoding=audio/raw;rate=16000&modelType=WHISPER&languageCode=ar';
    console.log("\n2. Connecting WebSocket (WHISPER ar)...");

    const ws = new WebSocket(wsUrl);

    ws.on('open', () => {
        console.log("   OPEN! (101 OK)");

        // Send TOKEN auth
        const authMsg = JSON.stringify({
            authenticationType: "TOKEN",
            token: token,
            compartmentId: "ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a",
        });
        console.log("   Sending TOKEN auth...");
        ws.send(authMsg);

        // After 2 seconds, send some silence (16kHz 16-bit PCM silence)
        setTimeout(() => {
            console.log("   Sending 1 second of silence...");
            const silence = Buffer.alloc(32000); // 1 second of 16kHz 16-bit silence
            ws.send(silence);
        }, 2000);

        // After 5 seconds, send STOP event
        setTimeout(() => {
            console.log("   Sending STOP...");
            ws.send(JSON.stringify({ event: "SEND_FINAL_RESULT" }));
        }, 5000);
    });

    ws.on('message', (data) => {
        const msg = data.toString();
        console.log("   <<< SERVER:", msg.substring(0, 500));
    });

    ws.on('error', (err) => {
        console.log("   !!! ERROR:", err.message);
    });

    ws.on('close', (code, reason) => {
        console.log("   --- CLOSED:", code, reason?.toString());
    });

    ws.on('unexpected-response', (req, res) => {
        let body = '';
        res.on('data', (c) => body += c);
        res.on('end', () => {
            console.log(`   !!! HTTP ${res.statusCode}: ${body.substring(0, 300)}`);
        });
    });

    setTimeout(() => { console.log("\n   TIMEOUT 20s"); ws.close(); process.exit(0); }, 20000);
}

main().catch(e => console.error("Fatal:", e));
