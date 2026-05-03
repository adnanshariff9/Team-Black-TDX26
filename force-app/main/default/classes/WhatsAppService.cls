public without sharing class WhatsAppService {

    @future(callout=true)
    public static void sendMessageAsync(String toNumber, String msg) {
        sendMessage(toNumber, msg);
    }

    public static void sendMessage(String toNumber, String msg){

        HttpRequest req = new HttpRequest();

        req.setEndpoint('callout:Twilio_API/Messages.json');
        req.setMethod('POST');

        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        Twilio_Config__mdt config = Twilio_Config__mdt.getInstance('Default');
        
        String fromNumber = config.From_Number__c;

        String body =
        'To=' + EncodingUtil.urlEncode('whatsapp:' + toNumber, 'UTF-8') +
        '&From=' + EncodingUtil.urlEncode(fromNumber, 'UTF-8') +
        '&Body=' + EncodingUtil.urlEncode(msg, 'UTF-8');

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('Status: ' + res.getStatus());
        System.debug('Response: ' + res.getBody());
    }
}