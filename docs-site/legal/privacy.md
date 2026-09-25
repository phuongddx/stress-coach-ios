# Privacy Policy

*Last updated: September 6, 2026*

This Privacy Policy describes and governs the manner in which Stress Monitor LTD, a company incorporated in England and Wales, with registered offices at 71-75 Shelton Street, Covent Garden, London, United Kingdom, WC2H 9JQ ("we", "us", "our" or the "Company"), collects, uses, maintains and discloses information about you when you use the StressMonitor mobile application ("StressMonitor" or the "App") and our other online services (collectively, the "Services").

Please read this Privacy Policy carefully before you start to use the Services. By accessing or using the Services, you accept and agree to be bound by this Privacy Policy and our Terms of Service, available at https://stressmonitor-docs.vercel.app/legal/terms (the "Terms"), which are incorporated herein by reference, and to comply with all applicable laws, rules and regulations (collectively, "Applicable Law"). If you do not want to agree to this Privacy Policy and the Terms, you must not access or use the Services.

## Personal Information We May Process

We may collect and process the following key categories of information:

- **Health Information**: see "Health Information from Apple Health" below.
- **AI Coaching Chat content**: the messages you send in AI Coaching Chat, together with any photos or videos you choose to attach, and the derived stress context described below (see "AI Coaching Chat & Third-Party Artificial Intelligence Technology").
- **Device and app identifiers**: identifiers transmitted to Google (Firebase Authentication / Google Sign-In) strictly for authentication and app functionality; never used for tracking or advertising.
- **Product interaction data**: basic app-interaction data (for example, which features are used) shared via Google Firebase for app functionality; never used for tracking or advertising.
- **Support communications**: if you contact us, we receive whatever information you choose to include (for example, your email address and the content of your message).

We do not collect your name, phone number, or payment details. The current version of the app offers no in-app purchases or subscriptions.

## Health Information from Apple Health

With your permission, StressMonitor connects to Apple Health (a "Third-Party Source") solely to read the following health information about you: heart rate variability (HRV), heart rate, resting heart rate, respiratory rate, blood oxygen (oxygen saturation), sleep analysis, step count, active energy burned, standing time, and workouts. The health information you permit us to read is collectively referred to as "Health Information."

StressMonitor has **read-only** access to Apple Health. We never write data back to Apple Health, and we never transmit raw HealthKit readings to our servers. All stress scoring from Health Information is computed **locally on your device** and stored on your device.

## How We Collect Information

- **From your device, with permission.** Health Information is read from Apple Health only after you grant the requested read permissions, and only on your device.
- **From you, when you use optional features.** When you open AI Coaching Chat, the app transmits the derived stress context and any messages or attachments you send, as described below.
- **Authentication.** When you use features that require a session, a Firebase authentication session is established — via anonymous sign-in or Google Sign-In, at your choice.

By providing us with this information or allowing us access to Apple Health, you consent to your information being collected, used, disclosed, processed and stored in accordance with this Privacy Policy.

## Where Your Information Is Stored

Health Information is, by default, stored and processed **locally on your device**. We do not store raw Health Information on our servers in the ordinary course of providing the Services.

The only health-derived data that leaves your device is the derived stress context described in the "AI Coaching Chat" section below, which is transmitted only when you initiate a chat interaction.

If you enable iCloud sync, your stress history syncs across your own Apple devices via Apple CloudKit. This data is end-to-end encrypted by Apple, is stored in your own iCloud account, and **we cannot access it**.

## AI Coaching Chat & Third-Party Artificial Intelligence Technology

AI Coaching Chat is an optional feature that you initiate. When you open a chat, the app sends the following derived values to StressMonitor's backend to generate a coaching response: your stress score, stress category, confidence, trend, and a per-factor breakdown of normalized HRV, heart rate, sleep, activity, and recovery scores. **Raw HealthKit sample values (for example, exact HRV readings in milliseconds or exact heart rate in bpm) are never included.**

This request carries an authenticated session (a Bearer JWT established via Firebase Authentication — anonymous sign-in or Google Sign-In). The messages you send, any photos or videos you attach, and this derived context are retained according to the backend's own chat-history retention policy, separate from the on-device health store.

To generate responses, we use third-party cloud hosting and artificial intelligence ("AI") technology providers. Processing by those providers is subject to their respective privacy policies and data handling practices.

We take the following steps to protect your privacy:

- We transmit only derived values, never raw health readings.
- We do not use Health Information or chat content for advertising or marketing.
- You control the feature: if you do not open AI Coaching Chat, no chat data is transmitted.

Please note that AI Coaching Chat generates responses based on your inputs and available derived context, and such responses may be inaccurate, incomplete, or inconsistent. AI Coaching Chat does not provide medical advice and should never be relied upon as a substitute for professional medical care, diagnosis, or treatment.

## How We Use Information

We may use the information described above for the following purposes:

- **To provide the Services.** Reading Health Information and computing your stress scores, trends, and factor breakdowns on your device.
- **To provide AI Coaching Chat.** Transmitting derived stress context and your messages to generate coaching responses.
- **To authenticate you.** Establishing and maintaining your session for features that require it.
- **To provide and improve customer service**, respond to your inquiries, notify you of changes to the Services, and maintain and improve functionality.
- **To protect the Services.** We may use information to protect the Company, the Services, and our users, and to prevent fraud, theft and misconduct.

We do not use Health Information or chat content for advertising, marketing, or profiling purposes.

## To Whom We Disclose Information

- **Service providers who act on our behalf.** Google (Firebase Authentication and related app-functionality services) and the third-party cloud hosting and AI technology providers that power AI Coaching Chat. These providers process information solely to deliver their services to us.
- **In accordance with applicable law.** We may disclose information to appropriate authorities if we believe disclosure is in accordance with, or required by, any applicable law, including lawful requests by public authorities.
- **In connection with a business transfer.** In the event of a reorganization, merger, acquisition, or sale of company assets, we may transfer information we collect to the relevant third party.
- **With your consent or at your direction.**

Other than as described in this Privacy Policy, we do not share your information.

## We Do Not Sell Your Personal Information

We do not sell or rent your personal information, and we do not share it with advertising networks or data brokers.

## Data We Do Not Collect

- Raw HealthKit readings are never transmitted to our servers. The only exception is the derived data described in "AI Coaching Chat" above.
- No third-party analytics or advertising trackers. Google/Firebase is used for sign-in and app functionality only.
- No advertising identifiers are collected or transmitted.
- HealthKit data is never used for advertising or marketing.

## Third-Party Links and Services

The App and our documentation site may contain links to third-party websites and services (for example, Apple's support pages). We do not control those third parties and are not responsible for their practices. Your use of third-party services is subject to their own terms and privacy policies.

## Your Choices

- **HealthKit permissions.** You may grant or revoke StressMonitor's access to Apple Health at any time in iOS Settings → Privacy & Security → Health.
- **AI Coaching Chat.** You choose whether to use AI Coaching Chat. If you do not open it, no chat data is transmitted.
- **Deleting your data.** You can delete all locally stored data at any time from StressMonitor → Settings → Data Management → Delete All Data. Deleting the App also removes locally stored data.
- **iCloud sync.** You may disable iCloud sync at any time in iOS Settings.
- **Requests.** You may request access to, or deletion of, your personal information by contacting us at support@stressmonitor.app.

## Information Security

We use commercially reasonable security technologies and procedures — including encrypted transport (HTTPS/TLS) for all network requests and end-to-end encryption for iCloud sync — to help protect your information from unauthorized access, use or disclosure. However, no method of transmission or storage is completely secure, and we cannot guarantee absolute security.

## How Long We Keep Your Information

- **On-device data** (health-derived scores, history, preferences) is stored on your device until you delete it (Settings → Data Management → Delete All Data) or uninstall the App.
- **Chat records** (messages, attachments, and derived context sent to the backend) are retained according to the backend's chat-history retention policy.
- **Session and authentication records** are retained only as long as necessary to provide the Services and for a reasonable period thereafter to fulfill outstanding obligations, resolve disputes, or comply with Applicable Law.

## Our Services Are Not Intended For Children

Our Services are not directed to children under the age of 18. We do not knowingly collect information, including personal information, from children. If we obtain actual knowledge that we have collected such information from children, we will promptly delete it. If you believe we have mistakenly collected such information, please contact us at support@stressmonitor.app.

## Information for European Economic Area and United Kingdom Residents

If you are a resident of the European Economic Area ("EEA") or the United Kingdom, you have certain rights under applicable data protection law (the "GDPR") regarding the processing of your personal information, including the rights to access, rectification, erasure, restriction of processing, data portability, and objection, as well as the right to lodge a complaint with your local supervisory authority.

We process personal information only where we have a legal basis to do so: to perform our contract with you (providing the Services), on the basis of your consent (features you enable, such as HealthKit access and AI Coaching Chat), where necessary to comply with legal obligations, or where necessary for our legitimate interests in operating, securing and improving the Services. Where processing is based on consent, you may withdraw it at any time, without affecting the lawfulness of processing based on consent before its withdrawal.

For contact details of your local data protection authority, please see: https://edpb.europa.eu/about-edpb/board/members_en

## Your California Privacy Rights

If you are a California resident, you have the right to know what personal information is collected about you and whether it is sold or disclosed, to request deletion of your personal information, and to be free from discrimination for exercising these rights. We do not sell personal information as that term is defined under California law. To exercise any of these rights, contact us at support@stressmonitor.app.

California's "Shine the Light" law (Civil Code Section § 1798.83) permits users to request certain information regarding our disclosure of personal information to third parties for direct marketing purposes. We do not disclose personal information to third parties for direct marketing purposes.

## "Do Not Track" Policy as Required by CalOPPA

Our Services do not respond to Do Not Track ("DNT") signals because we do not track users across third-party websites or services. You may enable or disable DNT in your web browser's preferences or settings.

## Governing Law and Jurisdiction

This Privacy Policy shall be governed by and construed in accordance with the laws of England and Wales. Any disputes relating to this Privacy Policy shall be subject to the exclusive jurisdiction of the courts of England and Wales.

## Changes to this Privacy Policy

We may update this Privacy Policy from time to time. We encourage you to check this page periodically for changes. Your continued use of the Services after changes are posted constitutes your acceptance of the revised policy.

## Contact Us

If you have any questions about this Privacy Policy, you can email us at **support@stressmonitor.app**, or write to us at:

Stress Monitor LTD
71-75 Shelton Street, Covent Garden
London, United Kingdom, WC2H 9JQ
