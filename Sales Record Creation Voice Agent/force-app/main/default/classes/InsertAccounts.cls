public with sharing class InsertAccounts {

    /**
     * @description Invocable method to create one or more Account records.
     * @param requests A list of AccountRequest objects, each containing details for an Account.
     * @return A list of AccountResponse objects, indicating the outcome for each requested Account creation.
     */
    @InvocableMethod(
        label='Create Accounts'
        description='Creates new Account records with the provided details. Handles multiple requests in a batch.'
        category='Account Management'
    )
    public static List<AccountResponse> createAccounts(List<AccountRequest> requests) {
        List<AccountResponse> responses = new List<AccountResponse>();
        // Initialize response list to match the size of requests, ensuring one response per request.
        for (Integer i = 0; i < requests.size(); i++) {
            responses.add(new AccountResponse());
        }

        List<AccountWrapper> accountsToProcess = new List<AccountWrapper>();

        // Validate requests and prepare Account sObjects
        for (Integer i = 0; i < requests.size(); i++) {
            AccountRequest req = requests.get(i);
            AccountResponse res = responses.get(i); // Get the pre-initialized response for this request
            res.success = false; // Default to failure, will be updated upon successful DML

            // --- Input Validation ---
            if (String.isBlank(req.name)) {
                res.message = 'Account Name is required.';
                continue; // Skip to the next request, response already marked as failure
            }

            if (req.numberOfEmployees != null && req.numberOfEmployees < 0) {
                res.message = 'Number of Employees cannot be negative.';
                continue;
            }

            if (req.annualRevenue != null && req.annualRevenue < 0) {
                res.message = 'Annual Revenue cannot be negative.';
                continue;
            }
            
            Account acc = new Account();
            acc.Name = req.name;

            // Optional Fields
            if (String.isNotBlank(req.accountNumber)) {
                acc.AccountNumber = req.accountNumber;
            }
            if (String.isNotBlank(req.phone)) {
                acc.Phone = req.phone;
            }
            if (String.isNotBlank(req.fax)) {
                acc.Fax = req.fax;
            }
            if (String.isNotBlank(req.website)) {
                acc.Website = req.website;
            }
            if (String.isNotBlank(req.industry)) {
                acc.Industry = req.industry; 
            }
            if (String.isNotBlank(req.type)) {
                acc.Type = req.type;
            }
            if (String.isNotBlank(req.ownership)) {
                acc.Ownership = req.ownership;
            }
            if (req.numberOfEmployees != null) {
                acc.NumberOfEmployees = req.numberOfEmployees;
            }
            if (req.annualRevenue != null) {
                acc.AnnualRevenue = req.annualRevenue;
            }
            if (String.isNotBlank(req.sicCode)) {
                acc.Sic = req.sicCode;
            }
            if (String.isNotBlank(req.tickerSymbol)) {
                acc.TickerSymbol = req.tickerSymbol;
            }
            if (String.isNotBlank(req.description)) {
                acc.Description = req.description;
            }
            if (String.isNotBlank(req.site)) {
                acc.Site = req.site;
            }

            // Billing Address
            acc.BillingStreet = String.isNotBlank(req.billingStreet) ? req.billingStreet : null;
            acc.BillingCity = String.isNotBlank(req.billingCity) ? req.billingCity : null;
            acc.BillingState = String.isNotBlank(req.billingState) ? req.billingState : null;
            acc.BillingPostalCode = String.isNotBlank(req.billingPostalCode) ? req.billingPostalCode : null;
            acc.BillingCountry = String.isNotBlank(req.billingCountry) ? req.billingCountry : null;

            // Shipping Address
            acc.ShippingStreet = String.isNotBlank(req.shippingStreet) ? req.shippingStreet : null;
            acc.ShippingCity = String.isNotBlank(req.shippingCity) ? req.shippingCity : null;
            acc.ShippingState = String.isNotBlank(req.shippingState) ? req.shippingState : null;
            acc.ShippingPostalCode = String.isNotBlank(req.shippingPostalCode) ? req.shippingPostalCode : null;
            acc.ShippingCountry = String.isNotBlank(req.shippingCountry) ? req.shippingCountry : null;
            
            if (String.isNotBlank(req.parentId)) {
                if (req.parentId.length() != 15 && req.parentId.length() != 18) {
                    res.message = 'Parent Account ID has an invalid format. It must be 15 or 18 characters long.';
                    continue;
                }
                try {
                    Id parentAccountId = Id.valueOf(req.parentId);
                    acc.ParentId = parentAccountId;
                } catch (System.StringException e) {
                    res.message = 'Invalid Parent Account ID format: ' + req.parentId + '. Error: ' + e.getMessage();
                    continue;
                }
            }
            
            // If all validations pass for this request, add to process list
            accountsToProcess.add(new AccountWrapper(i, acc));
        }

        // Extract actual Account sObjects to insert from wrappers
        List<Account> actualAccountsToInsert = new List<Account>();
        for (AccountWrapper wrapper : accountsToProcess) {
            actualAccountsToInsert.add(wrapper.acc);
        }

        // Perform DML operation if there are valid accounts to insert
        if (!actualAccountsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(actualAccountsToInsert, false); // Allow partial success

            // Process DML results and update responses
            for (Integer j = 0; j < saveResults.size(); j++) {
                Database.SaveResult sr = saveResults[j];
                AccountWrapper wrapper = accountsToProcess.get(j); 
                AccountResponse res = responses.get(wrapper.originalRequestIndex);

                if (sr.isSuccess()) {
                    res.success = true;
                    res.accountId = sr.getId();
                    res.message = 'Account created successfully.';
                } else {
                    res.success = false;
                    res.accountId = null;
                    String errorMessages = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages += err.getStatusCode() + ': ' + err.getMessage() + '. Fields: ' + String.join(err.getFields(), ', ') + ' ';
                    }
                    res.message = 'Error creating Account: ' + errorMessages.trim();
                }
            }
        }
        return responses;
    }

    /**
     * @description Helper inner class to associate an Account sObject with its original request index.
     */
    private class AccountWrapper {
        Integer originalRequestIndex;
        Account acc;

        AccountWrapper(Integer index, Account a) {
            this.originalRequestIndex = index;
            this.acc = a;
        }
    }

    /**
     * @description Defines the structure for requesting an Account creation.
     */
    public class AccountRequest {
        @InvocableVariable(label='Account Name' description='Name of the new account (e.g., "Global Corp Inc.").' required=true)
        public String name;

        @InvocableVariable(label='Account Number' description='Unique identifier or number for the account.' required=false)
        public String accountNumber;

        @InvocableVariable(label='Phone' description='Primary phone number for the account.' required=false)
        public String phone;
        
        @InvocableVariable(label='Fax' description='Fax number for the account.' required=false)
        public String fax;

        @InvocableVariable(label='Website' description='Website URL for the account (e.g., "http://www.globalcorp.com").' required=false)
        public String website;

        @InvocableVariable(label='Industry' description='Primary industry of the account (e.g., "Technology", "Finance"). Must be a valid picklist value.' required=false)
        public String industry;

        @InvocableVariable(label='Account Type' description='Type of account (e.g., "Prospect", "Customer - Direct", "Partner"). Must be a valid picklist value.' required=false)
        public String type;
        
        @InvocableVariable(label='Ownership' description='Ownership structure of the account (e.g., "Public", "Private"). Must be a valid picklist value.' required=false)
        public String ownership;

        @InvocableVariable(label='Number of Employees' description='Total number of employees at the account.' required=false)
        public Integer numberOfEmployees;

        @InvocableVariable(label='Annual Revenue' description='Annual revenue of the account.' required=false)
        public Decimal annualRevenue;
        
        @InvocableVariable(label='SIC Code' description='Standard Industrial Classification code for the account.' required=false)
        public String sicCode;

        @InvocableVariable(label='Ticker Symbol' description='Stock market ticker symbol for the account, if applicable.' required=false)
        public String tickerSymbol;

        @InvocableVariable(label='Description' description='A general description or notes about the account.' required=false)
        public String description;
        
        @InvocableVariable(label='Account Site' description='The specific location or site of the account (e.g., "Headquarters", "Main Branch").' required=false)
        public String site;

        // Billing Address Fields
        @InvocableVariable(label='Billing Street' description='Street address for billing purposes.' required=false)
        public String billingStreet;
        @InvocableVariable(label='Billing City' description='City for billing purposes.' required=false)
        public String billingCity;
        @InvocableVariable(label='Billing State/Province' description='State or province for billing purposes.' required=false)
        public String billingState;
        @InvocableVariable(label='Billing Zip/Postal Code' description='Zip or postal code for billing purposes.' required=false)
        public String billingPostalCode;
        @InvocableVariable(label='Billing Country' description='Country for billing purposes.' required=false)
        public String billingCountry;

        // Shipping Address Fields
        @InvocableVariable(label='Shipping Street' description='Street address for shipping purposes.' required=false)
        public String shippingStreet;
        @InvocableVariable(label='Shipping City' description='City for shipping purposes.' required=false)
        public String shippingCity;
        @InvocableVariable(label='Shipping State/Province' description='State or province for shipping purposes.' required=false)
        public String shippingState;
        @InvocableVariable(label='Shipping Zip/Postal Code' description='Zip or postal code for shipping purposes.' required=false)
        public String shippingPostalCode;
        @InvocableVariable(label='Shipping Country' description='Country for shipping purposes.' required=false)
        public String shippingCountry;
        
        @InvocableVariable(label='Parent Account ID' description='The 15 or 18-character ID of the parent Account for this account. Optional.' required=false)
        public String parentId;
    }

    /**
     * @description Defines the structure for the response of an Account creation attempt.
     */
    public class AccountResponse {
        @InvocableVariable(label='Account ID' description='The ID of the newly created Account record, if successful.')
        public String accountId;

        @InvocableVariable(label='Success' description='Indicates whether the Account creation was successful (true) or not (false).')
        public Boolean success;

        @InvocableVariable(label='Message' description='A status message providing details about the operation.')
        public String message;

        public AccountResponse() {
            this.success = false;
            this.message = '';
            this.accountId = null;
        }
    }
}
