20 May 2026:  
	&emsp;Updated UI   
	&emsp;Added Settings page  
	&emsp;Added all majors  
	&emsp;Fixed login bugs  

# BMCC Advisor

## AI-Powered Academic Assistant for BMCC Students

BMCC Advisor is an AI-powered iOS mobile application designed to help BMCC students receive instant academic assistance without waiting for advisor appointments. The application can answer questions, recommend schedules, explain majors, and help students track their academic progress.

The app was built using **Swift** for the iOS frontend and **Qwen:7B** as a locally hosted AI model. The goal of the project is to create a fast, customizable, and privacy-focused academic assistant specifically for BMCC students.

---

# Technologies Used

| Technology | Purpose |
|---|---|
| Swift | iOS mobile app development |
| Python | Backend development |
| FastAPI | API management and AI communication |
| Uvicorn | Running the FastAPI server |
| Qwen:7B | Local AI language model |
| Ollama | Running the AI model locally |
| Cloudflared | Secure connection between iOS app and backend |
| VS Code Tunnel | Remote backend development |
| JSON | Database and structured data storage |

---

# System Architecture

## Frontend (iOS App)

The mobile application was developed using Swift and designed specifically for iOS devices.

### App Layouts
- Login Page
- Build Profile Page
- Chat Interface
- Chat History
- Settings Page

The UI was designed to be simple and beginner-friendly for students.

---

## Backend (FastAPI + AI)

The backend uses **FastAPI** to manage communication between the mobile app and the AI model.

### Request Flow

1. The user sends a message from the iOS app.
2. The app automatically attaches profile information such as:
   - Student name
   - Major
   - Full-time or part-time status
   - Expected graduation year
   - Completed courses
3. The data is securely sent through **Cloudflared** using a custom domain.
4. FastAPI receives the request and sends it to the **Qwen:7B** AI model.
5. Qwen processes the request and generates a response.
6. The response is returned as JSON back to the iOS app.

---

# Schedule Generation System

If the user requests a class schedule, the AI returns structured JSON data including:
- Course names
- Course descriptions
- Major requirements
- Electives
- Prerequisite information

This allows the iOS app to visually display schedules using custom UI templates instead of plain text.

### UI Design Advantage

The iOS app uses placeholders and custom layouts to:
- Display course names in larger text
- Use different colors for course categories
- Organize schedules visually
- Make the interface more dynamic and modern

This improves readability and user experience compared to static text responses.

---

# AI and Database Optimization

Initially, all BMCC and CUNY program data was stored inside one giant JSON file containing over **140,000+ lines** of information.

## Optimization Process

To improve performance:
- The database was divided into **64 smaller JSON files**
- Each file represents a specific major or academic program
- Instead of reading the entire database, the AI only loads the file related to the student’s major

This significantly improved:
- AI response speed
- Processing time
- Accuracy of outputs

---

# Data Collection

The database was built by web scraping BMCC and CUNY websites to collect:
- Programs
- Majors
- Courses
- Prerequisites
- Degree requirements
- Course descriptions

The information is stored locally in JSON format.

---

# User Features

## Account System

When opening the app for the first time, users can:
- Create an account
- Continue as a guest

### User Profile Information

Students provide:
- First name
- Last name
- Major
- Full-time or part-time status
- Start semester
- Expected graduation year

This information is saved and automatically sent with user prompts to personalize AI responses.

---

## Settings Page

Users can:
- Edit their profile
- Change their major
- Update schedule preferences
- Delete their account

### Quick Access Links
The app also provides quick access to:
- DegreeWorks
- Schedule Builder

---

# Chat History System

The application stores previous conversations locally on the device.

### Benefits
- Access chats offline
- Continue previous conversations
- Provide conversational context to the AI model

Qwen can also read past conversations to improve response quality and maintain context.

---

# Security and Privacy

Student privacy is an important part of this project.

## Security Features
- Local AI hosting
- Local JSON database storage
- Secure Cloudflared tunneling
- Planned future encryption improvements

Since the AI runs locally using Ollama and Qwen:7B, no paid external AI APIs are required.

---

# Future Improvements

Planned improvements include:
- Better AI training and reduced hallucinations
- Streaming responses word-by-word
- Improved schedule recommendation logic
- More advanced academic advising
- Publishing the app officially on the Apple App Store
- Expanding support to more colleges and universities

---

# Developer Notes

This project was developed individually as a full-stack software engineering project.

The project combines:
- iOS mobile development
- AI integration
- Backend development
- API communication
- Data optimization
- UI/UX design
- Database structuring

The app was designed to solve a real-world problem experienced by BMCC students while creating a scalable academic advising platform.