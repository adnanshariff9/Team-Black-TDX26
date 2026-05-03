@JsonAccess(serializable='always' deserializable='always')
global class OncoAgentResponse {
    @AuraEnabled
    @InvocableVariable(description='High-level status for the action. Values include Success, NeedsInput, NoResults, and Error.')
    global String status;

    @AuraEnabled
    @InvocableVariable(description='Short display title for the response card.')
    global String title;

    @AuraEnabled
    @InvocableVariable(description='Patient-friendly response message.')
    global String message;

    @AuraEnabled
    @InvocableVariable(description='Machine-readable JSON payload for the custom Agentforce LWC renderer.')
    global String payloadJson;

    @AuraEnabled
    @InvocableVariable(description='Suggested next step for the agent or patient.')
    global String nextAction;
}
