# Onco Global Patient Agent 🏥🤖
**An autonomous "Digital Front Door" powered by Agentforce & Salesforce Health Cloud.**

*A Hackathon Submission by Team Black*

---

## 👥 The Team
*   **Adnan Shariff** *(Captain)*
*   **Abdul Raqeeb R**
*   **Idris Razaq**
*   **Shaik Zain**
*   **Mohammed Siddiq ulla**

---

## 📋 The Problem
Onco Global, a leading cancer care network, struggles with a critical human bottleneck: a seven-member contact center managing 450 daily calls for a base of 500,000 patients. 

In oncology, wait times are unacceptable. Long hold times cause immense friction for patients trying to book specialized care, and a lack of automated proactive outreach leads to high no-show rates—wasting vital clinical slots and delaying life-saving treatments.

## 💡 Our Solution
We built an AI-driven **Patient Scheduling Agent** that completely automates the appointment lifecycle across both Web and WhatsApp. By combining conversational AI with a custom-built scheduling interface, we deflect routine calls from human agents while giving patients instant, 24/7 access to care navigation.

### Key Features
*   **Conversational Triage:** Patients can ask complex, natural-language questions about oncology specialties, treatments, and hospital locations right on the Onco Global website.
*   **Dynamic Custom UI (LWC):** We bypassed standard chatbot limitations by building a custom Lightning Web Component (`oncoAgentResponseRenderer`) that renders directly inside the chat. Patients can easily filter by:
    *   Hospital Location (e.g., Mumbai vs. Delhi)
    *   Department (e.g., Medical Oncology vs. Radiation Oncology)
    *   Specific Doctors (or select "Next Available")
*   **Real-Time Scheduling Engine:** The bot connects securely to the Salesforce Scheduler API to query and reserve live clinical slots in Health Cloud with zero human intervention.
*   **Omnichannel WhatsApp Integration:** Patient care extends beyond the web. We integrated Salesforce Digital Engagement to push appointment confirmations, interactive reminders, and rescheduling options natively to the patient's WhatsApp.

---

## 🛠️ Architecture & Tech Stack
This project leverages the full power of the Salesforce ecosystem:

*   **Salesforce Health Cloud:** The core CRM and single source of truth for Providers, Facilities, and Patient data.
*   **Agentforce:** Powers the autonomous reasoning, intent classification, and action execution.
*   **Salesforce Scheduler API:** Handles complex routing, capacity mathematics, and slot generation (`lxscheduler`).
*   **Experience Cloud (LWR):** Hosts the public-facing patient portal.
*   **Messaging for In-App and Web (MIAW):** The bridge connecting Agentforce to the public website.
*   **Salesforce Digital Engagement:** Powers the WhatsApp integration for mobile self-service.
*   **Apex & LWC:** Custom backend controllers (`OncoSchedulerBase`) and frontend rendering logic.

---

## 🔮 Future Roadmap
If given more time, our team would implement the following enhancements:
1.  **Data Cloud Integration:** Ingest historical Electronic Health Record (EHR) data to allow the Agentforce bot to proactively suggest appointments based on specific, individualized oncology treatment protocols.
2.  **Voice Agents:** Expand the Agentforce deployment from text to voice, allowing elderly patients or those who prefer calling to interact with the same autonomous scheduling engine over the phone.

---
*Built with ❤️ for the 2026 Healthcare Hackathon.*
