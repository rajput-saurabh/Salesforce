public with sharing class AIAgentInvoker {
   @AuraEnabled 
   public static string invokeJavaAction(String userMessage) {
       try {
           // Create an instance of the invocable action with type ‘generateAiAgentResponse’ and name 'Agent_for_Setup'
           Invocable.Action action = Invocable.Action.createCustomAction('generateAiAgentResponse', 'Copilot_for_Salesforce');
          
           action.setInvocationParameter('userMessage', userMessage);
          
           // Execute the action
           List<Invocable.Action.Result> results = action.invoke();
           Invocable.Action.Result result = results[0];

           // Handle the response
           if (result.isSuccess()) {
               // Retrieve Agent Response
               String agentResponse = (String) result.getOutputParameters().get('agentResponse'); // Cast to String
               System.debug(agentResponse);
               return agentResponse;

           } else {
               return ('Java action execution failed: ' + result.getErrors());
           }
       } catch (Exception e) {
           return ('Error invoking Java action: ' + e.getMessage());
       }
   }
}