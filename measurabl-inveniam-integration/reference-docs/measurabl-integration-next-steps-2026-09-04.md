Sep 4, 2026

Moved from local Gemini notes. Companion diagram: [Measurabl document anchoring — embedded in existing services](../measurabl-anchoring-embedded-in-existing-services.md).

## **Measurabl integration next steps**

Invited [Yurii Kremenchutskiy](mailto:yurii.kremenchutskiy@dev.pro) [Andriian Chestnykh](mailto:andriian.chestnykh@dev.pro) [Zeljko Calic](mailto:zeljko.calic@dev.pro) [Bogdan Golod](mailto:bogdan.golod@dev.pro) [Valeriy Ilihmetov](mailto:valerii.ilikhmetov@dev.pro) [Kseniia Myrgorod](mailto:kseniia.myrgorod@dev.pro) [Oleksii Falko](mailto:oleksii.falko@dev.pro)

Attachments [Measurabl integration next steps](https://calendar.google.com/calendar/event?eid=MmF1MzdwYWtuaDE4M2QxYWQwZGhsaDU1NWggYm9nZGFuLmdvbG9kQGRldi5wcm8)

Meeting records [Transcript](https://docs.google.com/document/d/1n3RYjybgyMGPR-tulxzjDatBHzfFDFV6pFVPClIgjz8/edit?usp=drive_web&tab=t.epe1n4xwq15l) 

### **Summary**

Integration architecture discussion for measurable initiative via lazy onboarding and mainnet deployment.

**Lazy Onboarding Proposal**  
Shift from bulk provisioning to lazy onboarding for automatic client mapping. Avoid creating a new microservice and use existing endpoints.

**Mainnet Deployment Strategy**  
Target mainnet deployment to demonstrate real network demand for October showcase. Use a single master wallet instead of topping up individual client wallets.

### **Decisions**

## Needs Further Discussion

* **Data room creation trigger undefined** The trigger event for creating data rooms (e.g., per client, per portfolio, or per request) remains an open question requiring further definition.

* **Wallet top-up strategy pending** The strategy for wallet top-ups needs to be determined, specifically evaluating the use of a master wallet versus individual client wallets.

## Aligned

* **Lazy provisioning adopted for integration** The integration approach is set to use lazy provisioning, where clients, portfolios, and wallets are created on-demand upon request, replacing the previously discussed manual bulk upload process.

* **Presentation deadline is flexible** The October 20th deadline for the Measurable presentation is no longer a hard requirement, as the team will work around it if implementation is not fully complete.

* **Simplest integration approach prioritized** The team will prioritize the simplest technical implementation for the Measurabl integration and avoid developing a new microservice to prevent unnecessary engineering costs until formal requirements are established.

### **Next steps**

- [ ] \[Zeljko Calic\] Update Onboarding Checklist: Record the updates to the onboarding checklist by Monday.

- [ ] \[Andriian Chestnykh\] Create Architecture Diagram: Create a simplified diagram illustrating the communication flow between measurable and the BILLI component, including the lazy provisioning logic.

- [ ] \[Yurii Kremenchutskiy\] Verify Data Room Requirements: Consult with Rick Banker or Daria regarding specific data room requirements for the client mapping process.

- [ ] \[Andriian Chestnykh, Valeriy Ilihmetov\] Assign Keystone Tasks: Evaluate which team should handle the hub-related Keystone work.

- [ ] \[Bogdan Golod, Andriian Chestnykh\] Create Communication Diagram: Develop a high-level diagram outlining the communication flow between Measurabl and Invenium.

- [ ] \[Bogdan Golod, Andriian Chestnykh\] Draft Onboarding Requirements: Document the vision for batch and lazy onboarding processes and identify necessary internal answers from Invenium representatives.

- [ ] \[Andriian Chestnykh\] Send Confirmation: Forward the finalized diagram and open questions to the Measurabl team to solicit confirmation and feedback.

### **Details**

* **QA Onboarding Procedures**: Zeljko Calic, Oleksii Falko, and Maxim are organizing the onboarding process for the new quality assurance member, Alexander. They plan to hold introduction meetings and will update the existing onboarding checklist by the following Monday to ensure they are properly integrated into the project ([00:00:13](?tab=t.epe1n4xwq15l#heading=h.rgkd4h735pg8)).

* **Measurable Initiative Context and Mapping**: Bogdan Golod provided context regarding the measurable initiative, which involves mapping business data into the IO platform. Based on confirmation from Patrick Sprouse at Invenam, measurable will be structured as an organization where clients are represented as top-level portfolios. Any complex structures within a client will be handled via sub-portfolios ([00:01:27](?tab=t.epe1n4xwq15l#heading=h.s413dxvn5wvc)).

* **PRD Requirements and Wallet Placement**: Bogdan Golod developed a Product Requirements Document (PRD) based on current input, establishing that hub keys or ledgers must be stored at the portfolio level, rendering deal or data room level storage out of scope. The fallback strategy is to utilize the portfolio level if available, or the organization level if not, ensuring consistent functionality for all Invenam clients ([00:04:18](?tab=t.epe1n4xwq15l#heading=h.q23lxt68jpzz)).

* **Bulk Provisioning Concerns**: Bogdan Golod highlighted the need to manage bulk uploads of measurable clients into IO. There was a discussion regarding the efficiency of these processes and the need to avoid manual, repetitive work for the team ([00:05:43](?tab=t.epe1n4xwq15l#heading=h.r9t14gv1gij1)).

* **Proposal for Lazy Onboarding**: Yurii Kremenchutskiy proposed shifting from a bulk provisioning process to a "lazy onboarding" approach. This automated method would identify client requests and map the measurable domain to the Invenium domain upon demand, thereby eliminating the need for complex, manual synchronization scripts and allowing the system to handle newly created clients automatically ([00:07:08](?tab=t.epe1n4xwq15l#heading=h.k9u5gjdxsat9)).

* **Technical Implementation of Lazy Onboarding**: Yurii Kremenchutskiy and Bogdan Golod discussed the end-to-end workflow, where measurable would trigger calls to specific IO API endpoints using client-specific metadata. This would allow the Invenium system to distinguish between regular users and measurable users via organization keys, and check the database to verify if entities need creation or updates without requiring manual intervention ([00:15:12](?tab=t.epe1n4xwq15l#heading=h.mc45aroyfl5z)) ([00:31:38](?tab=t.epe1n4xwq15l#heading=h.ldny4bjpq91w)).

* **Resource Allocation for Implementation**: Yurii Kremenchutskiy noted that while the Keystone team has expertise regarding the Hub and blockchain, the implementation of these API endpoints could be handled by any Invenium developer. A final decision on team assignment will be managed by Andrean and Valeriy Ilihmetov ([00:19:25](?tab=t.epe1n4xwq15l#heading=h.eb84xzfkk8in)).

* **Data Room and Hierarchy Mapping**: The team discussed the necessity of mapping the hierarchy from measurable (client/portfolio/deal) to Invenium. Valeriy Ilihmetov clarified that data rooms must still be provisioned, as they maintain a one-to-one relationship with deals and require end-user involvement for the necessary AWS or Google keys ([00:35:33](?tab=t.epe1n4xwq15l#heading=h.11le1p49sem8)).

* **Measurable's Level of Interaction**: Bogdan Golod and Yurii Kremenchutskiy clarified that measurable representatives are primarily interested in the structured data (JSON/files) provided by Invenium rather than the user interface. Consequently, they do not require an active presence or manual interaction with the Invenium system, as the anchoring initiatives are primarily for Invenium's benefit rather than measurable's ([00:38:34](?tab=t.epe1n4xwq15l#heading=h.w08yv7bp0vd8)) ([00:46:58](?tab=t.epe1n4xwq15l#heading=h.5nqfbbhk12kv)).

* **Next Steps for Architecture Communication**: Yurii Kremenchutskiy recommended that Andrean create a simplified diagram explaining the communication flow, including the lazy provisioning logic, for the measurable architecture chat. The team agreed to avoid implementing delete or update operations for the time being, as those are not currently requested ([00:41:59](?tab=t.epe1n4xwq15l#heading=h.5mhp8pvl5u37)).

* **Hub Architecture and Parallel Structures**: Oleksii Falko expressed concern about the potential mismatch between the hierarchical structure in IO and the flatter structure in the Hub. Valeriy Ilihmetov clarified that the Hub application can operate independently, allowing for a "flat" structure of organizations that map to individual client portfolios without necessitating changes to the existing Hub implementation ([00:51:59](?tab=t.epe1n4xwq15l#heading=h.2uxg7zhoqaiz)).

* **Mainnet Deployment and Wallet Funding**: Andriian Chestnykh confirmed that the project will target the mainnet rather than a testnet to demonstrate real network demand. Regarding wallet funding, Valeriy Ilihmetov suggested using a single master wallet instead of topping up individual client wallets, though this remains a topic for future discussion ([00:54:44](?tab=t.epe1n4xwq15l#heading=h.rgdi0ybceuc0)).

* **Project Timeline and Communication**: Bogdan Golod provided an update on the October presentation deadline, noting that Daria indicated it is no longer a hard requirement, which relieves immediate pressure. Yurii Kremenchutskiy mentioned that communication regarding these architectural changes should proceed through the chat created by Rick, pending the addition of business representatives and project managers ([00:55:57](?tab=t.epe1n4xwq15l#heading=h.cjhn5o96a24n)).

* **Batch and Lazy Onboarding Communication Plan**: Yurii Kremenchutskiy directed the team to collaborate on describing the current vision for the batch and lazy onboarding process. This involves creating a high-level diagram to clearly communicate requirements to Measurabl and identifying necessary information from the Measurabl team, potentially with assistance from Daria. Andriian Chestnykh is responsible for sending this proposal to the Measurabl team to initiate a confirmation process or feedback loop ([00:58:59](?tab=t.epe1n4xwq15l#heading=h.2gzyqwc5yuya)). The goal is to reach an agreement on the communication and integration strategy before transitioning to task decomposition and ticket creation for the broader team ([01:00:38](?tab=t.epe1n4xwq15l#heading=h.1tmndxi8trtx)).

* **Timing for Ticket Creation**: Bogdan Golod initially proposed starting the ticketing process the following week. However, Yurii Kremenchutskiy suggested that because the Measurabl team is currently under heavy pressure, they may be highly responsive, making it advantageous to send inquiries immediately rather than delaying until the following week ([01:01:57](?tab=t.epe1n4xwq15l#heading=h.dpq4oi53vb9q)).

* **Provisioning Architecture Strategy**: Valeriy Ilihmetov inquired whether provisioning changes should be implemented via a new microservice or by modifying existing services ([01:01:57](?tab=t.epe1n4xwq15l#heading=h.dpq4oi53vb9q)). Yurii Kremenchutskiy advised against creating a new microservice, instead suggesting the use of an alternative endpoint on an existing service—such as the one used for document uploads—to keep the solution simple ([01:03:33](?tab=t.epe1n4xwq15l#heading=h.u6xa6gtuexiq)). While Valeriy Ilihmetov expressed a personal preference for a new microservice, Yurii Kremenchutskiy emphasized that in the absence of formalized business requirements, deadlines, or scalability plans, the team should avoid expensive engineering and prioritize the simplest effective solution ([01:04:58](?tab=t.epe1n4xwq15l#heading=h.yhibpvnrsoeg)).

* **Metadata Presentation**: Oleksii Falko noted that previous discussions regarding Daria’s presentation clarified how metadata published to the blockchain should be handled. This resolved concerns regarding the presentation of metadata to external parties who may not be familiar with the Invenium ecosystem ([01:06:33](?tab=t.epe1n4xwq15l#heading=h.23pvvol0rrzi)).

* **Presentation Types and Event Objectives**: Andriian Chestnykh sought clarification regarding the difference between presenting integration deliverables to Measurabl and the public showcase of the Invenium chain led by Pat ([01:06:33](?tab=t.epe1n4xwq15l#heading=h.23pvvol0rrzi)). Bogdan Golod clarified that the public event around October 20th is a general IO showcase; while having the Measurabl case ready by then would be beneficial for demonstrating scale, it is not a strict requirement if the work is not complete ([01:07:49](?tab=t.epe1n4xwq15l#heading=h.p8vmopxvvt57)). The engagement with Measurabl, which concludes in November, focuses on achieving milestones and improving processes, rather than just a final presentation. Oleksii Falko added that for the Invenium investor conference, the primary goal is to demonstrate significant user and transaction volume on the NVM chain, with Measurabl serving as a key data provider to demonstrate this utility ([01:09:04](?tab=t.epe1n4xwq15l#heading=h.8o42wunmny3j)).

*You should review Gemini's notes to make sure they're accurate. [Get tips and learn how Gemini takes notes](https://support.google.com/meet/answer/14754931)*

*How is the quality of **these specific notes?** [Take a short survey](https://google.qualtrics.com/jfe/form/SV_5bXzKQfylMIhSXc?confid=92TWdGBHnkgIYwKzN4IFDxIPOBEBMgUIigIgABgDCA&detailLevel=standard&hasImages=False&entryPoint=footerMain&isGoogler=False) to let us know your feedback, including how helpful the notes were for your needs.*