public class AppointmentReminderScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        WhatsAppNotificationHandler.sendReminders();
    }
}