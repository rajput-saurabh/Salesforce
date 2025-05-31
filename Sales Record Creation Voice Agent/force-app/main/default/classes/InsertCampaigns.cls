/**
 * @description Invocable Apex class to create Campaign records.
 * Handles batch requests and provides responses for each creation attempt.
 */
public with sharing class InsertCampaigns {

    /**
     * @description Invocable method to create one or more Campaign records.
     * @param requests A list of CampaignRequest objects, each containing details for a Campaign.
     * @return A list of CampaignResponse objects, indicating the outcome for each requested Campaign creation.
     */
    @InvocableMethod(
        label='Create Campaigns'
        description='Creates new Campaign records with the provided details. Handles multiple requests in a batch.'
        category='Campaign Management'
    )
    public static List<CampaignResponse> createCampaigns(List<CampaignRequest> requests) {
        List<CampaignResponse> responses = new List<CampaignResponse>();
        for (Integer i = 0; i < requests.size(); i++) {
            responses.add(new CampaignResponse());
        }

        List<CampaignWrapper> campaignsToProcess = new List<CampaignWrapper>();

        for (Integer i = 0; i < requests.size(); i++) {
            CampaignRequest req = requests.get(i);
            CampaignResponse res = responses.get(i);

            if (String.isBlank(req.name)) {
                res.message = 'Campaign Name is required.';
                continue;
            }
             if (req.startDate != null && req.endDate != null && req.startDate.daysBetween(req.endDate) < 0) {
                res.message = 'Campaign End Date cannot be before Start Date.';
                continue;
            }
            if (req.expectedRevenue != null && req.expectedRevenue < 0) {
                res.message = 'Expected Revenue cannot be negative.';
                continue;
            }
            if (req.budgetedCost != null && req.budgetedCost < 0) {
                res.message = 'Budgeted Cost cannot be negative.';
                continue;
            }
            if (req.actualCost != null && req.actualCost < 0) {
                res.message = 'Actual Cost cannot be negative.';
            }


            Campaign camp = new Campaign();
            camp.Name = req.name;
            camp.IsActive = req.isActive; // Defaults to false if not provided by InvocableVariable

            // Optional Fields
            camp.ParentId = String.isNotBlank(req.parentId) ? Id.valueOf(req.parentId) : null;
            camp.Type = String.isNotBlank(req.type) ? req.type : null; // Valid picklist API name
            camp.Status = String.isNotBlank(req.status) ? req.status : null; // Valid picklist API name
            camp.StartDate = req.startDate;
            camp.EndDate = req.endDate;
            camp.ExpectedRevenue = req.expectedRevenue;
            camp.BudgetedCost = req.budgetedCost;
            camp.ActualCost = req.actualCost;
            camp.ExpectedResponse = req.expectedResponse; // Percentage
            camp.NumberSent = req.numberSent;
            camp.Description = String.isNotBlank(req.description) ? req.description : null;
            
            if (String.isNotBlank(req.parentId)) {
                 if (req.parentId.length() != 15 && req.parentId.length() != 18) {
                    res.message = 'Parent Campaign ID has an invalid format. It must be 15 or 18 characters long.';
                    continue;
                }
                try {
                    camp.ParentId = Id.valueOf(req.parentId);
                } catch (System.StringException e) {
                    res.message = 'Invalid Parent Campaign ID format: ' + req.parentId + '. Error: ' + e.getMessage();
                    continue;
                }
            }


            campaignsToProcess.add(new CampaignWrapper(i, camp));
        }

        List<Campaign> actualCampaignsToInsert = new List<Campaign>();
        for (CampaignWrapper wrapper : campaignsToProcess) {
            actualCampaignsToInsert.add(wrapper.campaignRec);
        }

        if (!actualCampaignsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(actualCampaignsToInsert, false);

            for (Integer j = 0; j < saveResults.size(); j++) {
                Database.SaveResult sr = saveResults[j];
                CampaignWrapper wrapper = campaignsToProcess.get(j);
                CampaignResponse res = responses.get(wrapper.originalRequestIndex);

                if (sr.isSuccess()) {
                    res.success = true;
                    res.campaignId = sr.getId();
                    res.message = 'Campaign created successfully.';
                } else {
                    String errorMessages = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages += err.getStatusCode() + ': ' + err.getMessage() + '. Fields: ' + String.join(err.getFields(), ', ') + ' ';
                    }
                    res.message = 'Error creating Campaign: ' + errorMessages.trim();
                }
            }
        }
        return responses;
    }

    private class CampaignWrapper {
        Integer originalRequestIndex;
        Campaign campaignRec;
        CampaignWrapper(Integer index, Campaign camp) {
            this.originalRequestIndex = index;
            this.campaignRec = camp;
        }
    }

    public class CampaignRequest {
        @InvocableVariable(label='Campaign Name' description='Name of the campaign.' required=true)
        public String name;

        @InvocableVariable(label='Is Active' description='Indicates if the campaign is currently active. Defaults to false if not specified.' required=false)
        public Boolean isActive = false; // Default value

        @InvocableVariable(label='Parent Campaign ID' description='ID of the parent campaign, if this is a child campaign. Must be a valid 15 or 18 character Salesforce ID.' required=false)
        public String parentId;

        @InvocableVariable(label='Campaign Type' description='Type of campaign (e.g., "Webinar", "Email", "Conference"). Must be a valid picklist API name.' required=false)
        public String type;

        @InvocableVariable(label='Campaign Status' description='Status of the campaign (e.g., "Planned", "In Progress", "Completed"). Must be a valid picklist API name.' required=false)
        public String status;

        @InvocableVariable(label='Start Date' description='Start date of the campaign. Format: YYYY-MM-DD.' required=false)
        public Date startDate;

        @InvocableVariable(label='End Date' description='End date of the campaign. Format: YYYY-MM-DD.' required=false)
        public Date endDate;

        @InvocableVariable(label='Expected Revenue' description='Expected revenue from this campaign.' required=false)
        public Decimal expectedRevenue;

        @InvocableVariable(label='Budgeted Cost' description='Budgeted cost for this campaign.' required=false)
        public Decimal budgetedCost;

        @InvocableVariable(label='Actual Cost' description='Actual cost incurred for this campaign.' required=false)
        public Decimal actualCost;

        @InvocableVariable(label='Expected Response (%)' description='Expected response rate in percentage (e.g., 10 for 10%).' required=false)
        public Double expectedResponse; // Stored as Percent in Salesforce, input as Double

        @InvocableVariable(label='Number Sent' description='Number of individuals the campaign was sent to or targeted.' required=false)
        public Double numberSent; // Stored as Number in Salesforce, input as Double

        @InvocableVariable(label='Description' description='Detailed description of the campaign.' required=false)
        public String description;
    }

    public class CampaignResponse {
        @InvocableVariable(label='Campaign ID' description='ID of the newly created Campaign.')
        public String campaignId;
        @InvocableVariable(label='Success' description='True if creation was successful.')
        public Boolean success;
        @InvocableVariable(label='Message' description='Status message.')
        public String message;

        public CampaignResponse() {
            this.success = false; this.message = ''; this.campaignId = null;
        }
    }
}