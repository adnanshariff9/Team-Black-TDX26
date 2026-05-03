public without sharing class OncoAuthController {
    
    // Wrapper class to send user data to LWC safely
    public class UserData {
        @AuraEnabled public Boolean isGuest;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
    }

    @AuraEnabled(cacheable=true)
    public static UserData getUserState() {
        UserData data = new UserData();
        // Salesforce recognizes unauthenticated community users as 'Guest'
        data.isGuest = UserInfo.getUserType() == 'Guest';
        
        if (!data.isGuest) {
            User u = [SELECT Id, FirstName, LastName, Email, Phone FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            data.firstName = u.FirstName;
            data.lastName = u.LastName;
            data.email = u.Email;
            data.phone = u.Phone;
        }
        return data;
    }

    @AuraEnabled
    public static String updateProfile(String firstName, String lastName, String phone) {
        try {
            User u = new User(Id = UserInfo.getUserId());
            u.FirstName = firstName;
            u.LastName = lastName;
            u.Phone = phone;
            update u;
            return 'Profile updated successfully!';
        } catch (Exception e) {
            throw new AuraHandledException('Error updating profile: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String doLogin(String username, String password) {
        try {
            PageReference pageRef = Site.login(username, password, '/OncoGlobalHealth');
            return (pageRef != null) ? pageRef.getUrl() : null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String doRegister(String firstName, String lastName, String email, String password) {
        try {
            User u = new User();
            u.FirstName = firstName;
            u.LastName = lastName;
            u.Username = email; 
            u.Email = email;
            u.CommunityNickname = email.substringBefore('@') + String.valueOf(Crypto.getRandomInteger()).substring(0,4);
            
            String userId = Site.createPortalUser(u, null, password);
            return (userId != null) ? doLogin(email, password) : null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String doForgotPassword(String username) {
        try {
            return Site.forgotPassword(username) ? 'Success' : 'Error resetting password.';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}