# AI Receptionist Chat Widget

A modern, embeddable chat widget that integrates with your Rails AI Receptionist backend to provide intelligent customer support on websites.

## 🚀 Quick Start

### Prerequisites
- Rails backend running on `http://localhost:3000`
- Node.js 16+ for development

### Development Setup

1. **Install dependencies**
   ```bash
   cd frontend
   npm install
   ```

2. **Start development server**
   ```bash
   npm run dev
   ```
   The widget will be available at `http://localhost:8080`

3. **Test the widget**
   Open `http://localhost:8080` in your browser to see the demo page with the chat widget.

## 📦 Production Deployment

### Build for Production
```bash
npm run build:prod
```
This creates a minified `ai-chat-widget.min.js` file in the `dist/` directory.

### Serve the Widget File
Host the built JavaScript file on your server (e.g., CDN, static file server) and provide the URL to your clients.

## 🔧 Integration

### Simple Embed (Recommended)
Add this script tag before the closing `</body>` tag:

```html
<script 
  src="YOUR_WIDGET_URL/ai-chat-widget.min.js"
  data-ai-chat-widget
  data-api-url="https://your-api.com/api/v1"
  data-phone-number-id="123"
  data-theme="blue"
  data-welcome-message="Hi! How can I help you?"
  data-enable-faq="true">
</script>
```

### Manual Initialization
For more control:

```html
<script src="YOUR_WIDGET_URL/ai-chat-widget.min.js"></script>
<script>
  AIChatWidget.init({
    apiBaseUrl: 'https://your-api.com/api/v1',
    phoneNumberId: '123',
    theme: 'blue',
    position: 'bottom-right',
    welcomeMessage: 'Hi! How can I help you?',
    enableFAQ: true
  });
</script>
```

## ⚙️ Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `apiBaseUrl` | string | `http://localhost:3000/api/v1` | Your Rails API base URL |
| `phoneNumberId` | string | `null` | Phone number ID for this website |
| `theme` | string | `'blue'` | Color theme: 'blue', 'green', 'purple' |
| `position` | string | `'bottom-right'` | Widget position: 'bottom-right', 'bottom-left', 'top-right', 'top-left' |
| `welcomeMessage` | string | `'Hi! How can I help you today?'` | Initial greeting message |
| `placeholder` | string | `'Type your message...'` | Input placeholder text |
| `enableFAQ` | boolean | `true` | Show FAQ suggestions button |
| `enableHumanHandoff` | boolean | `true` | Enable escalation to human support |

## 🔌 Backend Integration

The widget integrates with your Rails API using these endpoints:

### Required Endpoints
- `GET /api/v1/health` - Health check
- `GET /api/v1/phone_numbers/:id/faqs` - Get FAQs for phone number
- `POST /api/v1/calls` - Create new call session
- `POST /api/v1/calls/:id/transcript` - Add message to conversation

### Phone Number Setup
1. Create a phone number record in your Rails backend
2. Add FAQs for that phone number
3. Use the phone number ID in the widget configuration

Example API call to get phone number ID:
```bash
curl http://localhost:3000/api/v1/phone_numbers
```

## 🎨 Customization

### Themes
- **Blue** (default): Professional blue gradient
- **Green**: Fresh green/teal gradient  
- **Purple**: Soft purple/pink gradient

### Custom Styling
The widget uses CSS classes that can be overridden:
- `.chat-widget` - Main container
- `.chat-container` - Chat window
- `.chat-toggle` - Toggle button
- `.message` - Message bubbles

## 📱 Features

### ✅ Core Features
- **Real-time Chat**: Instant messaging interface
- **FAQ Integration**: Search and display frequently asked questions
- **Call Tracking**: Creates call records in your backend
- **Conversation Logging**: Saves all messages as transcripts
- **Mobile Responsive**: Works on all devices
- **Multiple Themes**: Professional color schemes
- **Easy Embedding**: Single script tag integration

### 🤖 AI Features
- **Intelligent Responses**: Context-aware replies
- **FAQ Matching**: Automatic FAQ suggestions based on user queries
- **Conversation Context**: Maintains chat history
- **Human Handoff**: Escalation to live support

### 📊 Analytics Integration
All conversations are tracked in your Rails backend:
- Call duration and status
- Message transcripts
- Customer sentiment
- FAQ effectiveness

## 🚀 Deployment Examples

### Option 1: CDN Hosting
```html
<!-- Replace with your CDN URL -->
<script src="https://cdn.yoursite.com/ai-chat-widget.min.js" data-ai-chat-widget data-api-url="https://api.yoursite.com/api/v1" data-phone-number-id="123"></script>
```

### Option 2: Self-Hosted
```html
<script src="/assets/ai-chat-widget.min.js" data-ai-chat-widget data-api-url="/api/v1" data-phone-number-id="123"></script>
```

## 🔒 Security Considerations

- **CORS**: Ensure your Rails API allows requests from client domains
- **Rate Limiting**: Implement rate limiting on your API endpoints
- **Input Validation**: Validate all chat inputs on the backend
- **HTTPS**: Always use HTTPS in production

## 🐛 Troubleshooting

### Common Issues

**Widget not appearing**
- Check browser console for JavaScript errors
- Verify the script URL is accessible
- Ensure the container element exists

**API connection failed**
- Verify Rails backend is running
- Check CORS configuration
- Confirm API base URL is correct

**FAQs not loading**
- Verify phone number ID exists in database
- Check that FAQs are associated with the phone number
- Review API endpoint permissions

### Debug Mode
For development, the widget logs debug information to the browser console.

## 📋 Browser Support

- Chrome 70+
- Firefox 70+
- Safari 12+
- Edge 79+
- Mobile browsers (iOS Safari, Chrome Mobile)

## 🔄 Updates and Maintenance

### Version Management
- Use semantic versioning for widget releases
- Test thoroughly before deploying updates
- Provide migration guides for breaking changes

### Monitoring
- Monitor API response times
- Track widget load times
- Monitor conversation completion rates

---

## 🆘 Support

For support with the AI Receptionist Chat Widget:
1. Check this documentation
2. Review the browser console for errors
3. Test API endpoints directly
4. Check Rails backend logs