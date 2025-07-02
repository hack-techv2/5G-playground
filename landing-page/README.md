# 5G Playground - Landing Page

This is a custom HTML/CSS/JS landing page for the 5G Playground cybersecurity challenges platform, created as an alternative to the CTFd platform.

## Features

- Modern, responsive design with HTML5, CSS3, and JavaScript
- Real-time status checking of all challenge services
- Interactive challenge cards with port information
- Modal dialogs for detailed challenge information
- Easter egg functionality (click the main title 5 times!)
- Font Awesome icons for enhanced UI

## Tech Stack

- **Frontend**: HTML5, CSS3 (with CSS Grid, Flexbox, CSS Variables), Vanilla JavaScript ES6+
- **Web Server**: Nginx (Alpine Linux based)
- **Containerization**: Docker & Docker Compose

## Directory Structure

```
landing-page/
├── css/
│   └── styles.css           # Main stylesheet
├── js/
│   └── script.js           # JavaScript functionality
├── images/
│   └── hero-bg.jpg         # Background image
├── index.html              # Main HTML file
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Docker Compose configuration
└── README.md              # This file
```

## Quick Start

### Prerequisites
- Docker and Docker Compose installed on your system

### Running the Landing Page

1. **Navigate to the project directory:**
   ```bash
   cd landing-page
   ```

2. **Build and start the container:**
   ```bash
   docker-compose up -d
   ```

3. **Access the landing page:**
   Open your browser and navigate to: `http://localhost`

4. **Stop the service:**
   ```bash
   docker-compose down
   ```

## Configuration

### Adding New Challenges

To add new challenges to the landing page:

1. Edit `index.html`
2. Add a new challenge card in the challenge grid section:
   ```html
   <div class="challenge-card" data-port="XXXX">
       <div class="challenge-icon">
           <i class="fas fa-your-icon"></i>
       </div>
       <h3>Your Challenge Name</h3>
       <p>Challenge description.</p>
       <div class="challenge-details">
           <span class="port">Port: XXXX</span>
           <a href="javascript:void(0)" onclick="window.open('http://' + window.location.hostname + ':XXXX', '_blank')" class="btn-small">Launch</a>
       </div>
   </div>
   ```
3. Update the port number in the `data-port` attribute
4. Restart the container

### Customizing Styles

- Edit `css/styles.css` to modify colors, fonts, layout, etc.
- CSS variables are defined in `:root` for easy theme customization
- The design is fully responsive and mobile-friendly

### Modifying Functionality

- Edit `js/script.js` to add new features or modify existing behavior
- The script includes status checking, modal handling, smooth scrolling, and easter egg functionality

## Port Configuration

The landing page runs on port 80 by default. To change this:

1. Edit `docker-compose.yml`
2. Change the ports mapping: `"DESIRED_PORT:80"`
3. Restart the container

## Development

For development without Docker:

1. Use any local web server (e.g., Python's built-in server):
   ```bash
   python -m http.server 8080
   ```
2. Navigate to `http://localhost:8080`

## Troubleshooting

- **Port conflicts**: If port 80 is in use, change the port mapping in docker-compose.yml
- **File permission issues**: Ensure Docker has access to the project directory
- **Container not starting**: Check logs with `docker-compose logs landing-page`
- **Challenges not responding**: The status checker will show which services are offline

## Features Overview

- **Status Monitoring**: Automatically checks if challenge services are online
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Modern UI**: Clean, professional design with smooth animations
- **Interactive Elements**: Hover effects, modal dialogs, smooth scrolling
- **Accessibility**: Proper HTML semantics and keyboard navigation support

## Notes

- Font Awesome icons are loaded from CDN for better performance
- The background image can be replaced by updating the `hero-bg.jpg` file
- All challenge links open in new tabs/windows
- The easter egg adds some fun interactivity for curious users 