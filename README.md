<div align="center">

# 🛡️ PrintGuard
**End-to-End Industrial Defect Detection & AI Surveillance System**

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)](https://firebase.google.com)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-%23FF6F00.svg?style=for-the-badge&logo=TensorFlow&logoColor=white)](https://tensorflow.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com)

*Built during an AI Engineering Internship at RCI3D*

</div>

---

## 🚨 The Problem
In industrial manufacturing, machine defects lead to costly downtime. Operators need a way to instantly detect anomalies in real-time, understand the root cause of the defect, and get actionable solutions without waiting for a specialist.

## 💡 The Solution
**PrintGuard** is a smart surveillance mobile app that uses a deployed Computer Vision model to monitor machine output via live-stream. If the defect rate exceeds an **80% error threshold**, the app instantly triggers a push notification. Operators can then chat with an integrated **LLM + RAG assistant** to diagnose *why* the defect happened and *how* to fix it.

---

## ✨ Key Features

- 📸 **Real-Time Computer Vision:** Live-stream and static image capture connected to a Python/TensorFlow backend.
- 🔔 **Smart Surveillance Alerts:** Automated push notifications via Firebase Cloud Messaging (FCM) when machine errors exceed the 80% threshold.
- 🧠 **AI Troubleshooting Assistant:** Integrated RAG pipeline that acts as an expert, answering why a defect occurred and how to resolve it.
- 🔐 **Secure Auth & History:** Firebase Authentication for secure login, with all detection history stored in Firestore.

---

## 🏗️ System Architecture

```text
[Flutter Mobile App] 
       │ 
       ├── (REST API) ──> [FastAPI Backend] ──> [TensorFlow CV Model]
       │                        │
       │                        └─────────────> [LLM + RAG Assistant]
       │
       └── (Auth/DB) ───> [Firebase Auth & Firestore]
🚀 How to Run
Clone the repository:

bash
git clone https://github.com/safwenbenali/printguard-mobile-app.git
Navigate to the directory:

bash
cd printguard-mobile-app
Install dependencies:

bash
flutter pub get
Set up Firebase: Add your google-services.json (Android) and GoogleService-Info.plist (iOS) to the respective folders.

Run the app:

bash
flutter run
🔗 Related Repositories
🧠 AI Backend & RAG Pipeline: PrintGuard-AI-Server

<div align="center"> <i>Developed by <a href="https://linkedin.com/in/YOUR-LINKEDIN-URL">Safwen Ben Ali</a></i> </div> ``
