# Blind Assistant App

**Blind Assistant App** is a Flutter application designed to assist blind users by providing vital information using text-to-speech (TTS) and location-based services. The app helps users navigate and provides important alerts based on location and device data.

## Features

- **Text-to-Speech (TTS)**: Speaks the current location, nearby facilities, and alerts based on serial data (e.g., heart rate and obstacle distance).
- **Location Services**: Retrieves and announces the user's current GPS coordinates.
- **Nearby Facilities**: Fetches nearby sports facilities based on the user's location.
- **Serial Communication**: Reads serial data for distance and heart rate from a connected USB device.
- **Alert**: Alert when an obstacle is detected within 3 meters
- **Gesture-Based Interaction**:
  - **Single Tap**: Announces the current location.
  - **Double Tap**: Fetches and announces the nearest sports facility.
  - **Long Press**: Announces the heart rate condition in real-time

## Getting Started

To get started with this project, follow the instructions below.

### Prerequisites

Ensure you have **Flutter** installed on your development machine. If you haven't installed Flutter yet, follow the instructions in the official [Flutter installation guide](https://flutter.dev/docs/get-started/install).

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/blind-assistant-app.git
