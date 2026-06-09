# 🎙️ Pody — AI Podcast Platform

A cross-platform AI podcast application that enables users to discover, generate, and stream AI-powered audio content. Built with a **microservices architecture** in Go and a Flutter mobile client.

## ✨ Features

- **AI Podcast Generation** — Automatically generates podcast audio from articles using Google Gemini AI and TTS models
- **Article Aggregation** — Crawls and indexes articles from various sources with scheduled updates
- **Semantic Search** — Vector-based article search powered by pgvector and Gemini Embedding API
- **User Authentication** — JWT-based auth with Google Sign-In, email verification, and password reset
- **Real-Time Notifications** — Event-driven notification system via Kafka message broker
- **Audio Streaming** — Stream AI-generated podcasts with background playback and offline caching
- **Object Storage** — MinIO for storing podcast audio files and user avatars

## 🏗️ Architecture

```
┌─────────────┐         ┌──────────────────┐
│ Flutter App  │ ──────▶ │   API Gateway    │ (Go, chi)
└─────────────┘         └────────┬─────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Identity Service │  │ Content Service  │  │   AI Service     │
│ (Go, pgx, JWT)   │  │ (Go, pgx, chi)   │  │ (Go, Gemini API) │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                      │
         ▼                     ▼                      ▼
   ┌──────────┐          ┌──────────┐           ┌──────────┐
   │ Postgres │          │ Postgres │           │ Postgres │
   └──────────┘          └──────────┘           └──────────┘

          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Article Service  │  │Embedding Service │  │Notification Svc  │
│ (Python, FastAPI)│  │(Python, pgvector)│  │ (Go, Kafka)      │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                      │
         ▼                     ▼                      ▼
   ┌──────────┐          ┌──────────┐           ┌──────────┐
   │ Postgres │          │ pgvector │           │ Postgres │
   └──────────┘          └──────────┘           └──────────┘

               ┌───────────┐  ┌───────────┐  ┌───────────┐
               │   Kafka   │  │   Redis   │  │   MinIO   │
               │  (Events) │  │  (Cache)  │  │ (Storage) │
               └───────────┘  └───────────┘  └───────────┘
```

## 🛠️ Tech Stack

### Backend (Microservices)
| Service | Language | Key Dependencies |
|---|---|---|
| **API Gateway** | Go | chi, golang-jwt |
| **Identity Service** | Go | pgx, golang-jwt, kafka-go, minio-go, Google OAuth |
| **Content Service** | Go | pgx, chi |
| **AI Service** | Go | Google Gemini AI, Google TTS, Brave Search |
| **Notification Service** | Go | pgx, kafka-go, SMTP |
| **Article Service** | Python | FastAPI, Redis, Kafka, MinIO, Gemini AI |
| **Embedding Service** | Python | pgvector, Gemini Embedding API, Kafka |

### Infrastructure
| Technology | Purpose |
|---|---|
| **PostgreSQL 16** | Primary database (per-service isolation) |
| **pgvector** | Vector similarity search for embeddings |
| **Apache Kafka** | Event-driven messaging between services |
| **Debezium (CDC)** | Change Data Capture for article sync |
| **Redis 7** | Caching layer |
| **MinIO** | S3-compatible object storage for audio & avatars |
| **Docker Compose** | Full-stack container orchestration (18+ services) |

### Mobile
| Technology | Purpose |
|---|---|
| **Flutter + Dart** | Cross-platform mobile app |
| **Hive** | Local storage & offline caching |
| **Firebase** | Push notifications |

## 📁 Project Structure

```
├── server/
│   ├── api-gateway/          # Go — Reverse proxy, JWT validation, routing
│   ├── identity-service/     # Go — User auth, OAuth, profile management
│   ├── content-service/      # Go — Podcast content CRUD
│   ├── ai-service/           # Go — AI podcast generation (Gemini + TTS)
│   ├── notification-service/ # Go — Email notifications via Kafka consumers
│   ├── article_service/      # Python — Article crawling & indexing
│   ├── embedding_service/    # Python — Vector embeddings (pgvector)
│   ├── migrations/           # Database migrations
│   ├── schema/               # Shared Protobuf/schemas
│   └── sql/                  # SQL initialization scripts
│
├── flutter-app/              # Flutter mobile client
├── debezium/                 # CDC connector configuration
├── tools/                    # Development utilities
└── docker-compose.yml        # Full infrastructure (18+ containers)
```

## 🚀 Getting Started

### Prerequisites
- Docker & Docker Compose
- Go 1.26+
- Flutter SDK
- Google Cloud credentials (for Gemini AI & TTS)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/pody-team/pody-app.git
cd pody-app

# Configure environment
cp .env.example .env  # Edit with your API keys & credentials

# Start all services
docker compose up -d

# Run Flutter app
cd flutter-app
flutter pub get
flutter run
```

## 👥 Team

- **4 members** — Backend (Go microservices), AI/ML pipeline, Mobile (Flutter), DevOps

## 📄 License

This project is for educational purposes.
