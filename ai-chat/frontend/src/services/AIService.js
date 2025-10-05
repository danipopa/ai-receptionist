/**
 * AI Service for integrating with various AI providers
 * Supports OpenAI, Hugging Face, and other APIs
 */

class AIService {
  constructor(config = {}) {
    this.provider = config.provider || 'none'; // 'openai', 'huggingface', 'gemini', 'none'
    this.apiKey = config.apiKey;
    this.model = config.model || 'gpt-3.5-turbo';
    this.baseUrl = config.baseUrl;
    this.enabled = this.provider !== 'none' && this.apiKey;
  }

  /**
   * Generate AI response using the configured provider
   */
  async generateResponse(userMessage, context = {}) {
    if (!this.enabled) {
      throw new Error('AI service not configured');
    }

    const systemPrompt = this.buildSystemPrompt(context);
    
    switch (this.provider) {
      case 'openai':
        return await this.callOpenAI(userMessage, systemPrompt);
      case 'huggingface':
        return await this.callHuggingFace(userMessage, systemPrompt);
      case 'gemini':
        return await this.callGemini(userMessage, systemPrompt);
      default:
        throw new Error(`Unsupported AI provider: ${this.provider}`);
    }
  }

  /**
   * Build system prompt with business context
   */
  buildSystemPrompt(context) {
    const { businessInfo = {}, faqs = [], websiteContent = [] } = context;
    
    let prompt = `You are a helpful AI receptionist for ${businessInfo.name || 'our business'}. `;
    
    if (businessInfo.hours) {
      prompt += `Our business hours are: ${businessInfo.hours}. `;
    }
    
    if (businessInfo.services && businessInfo.services.length > 0) {
      prompt += `We offer these services: ${businessInfo.services.join(', ')}. `;
    }
    
    if (businessInfo.phone || businessInfo.email) {
      prompt += `Contact information - `;
      if (businessInfo.phone) prompt += `Phone: ${businessInfo.phone}. `;
      if (businessInfo.email) prompt += `Email: ${businessInfo.email}. `;
    }
    
    if (faqs.length > 0) {
      prompt += `\n\nFrequently Asked Questions:\n`;
      faqs.slice(0, 10).forEach(faq => {
        prompt += `Q: ${faq.question}\nA: ${faq.answer}\n\n`;
      });
    }
    
    if (websiteContent.length > 0) {
      prompt += `\n\nWebsite Content:\n`;
      websiteContent.forEach(content => {
        prompt += `${content.title}: ${content.content}\n`;
      });
    }
    
    prompt += `\n\nPlease provide helpful, accurate responses based on this information. If you don't have specific information, offer to connect the user with a human agent.`;
    
    return prompt;
  }

  /**
   * Call OpenAI API
   */
  async callOpenAI(userMessage, systemPrompt) {
    try {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userMessage }
          ],
          max_tokens: 300,
          temperature: 0.7
        })
      });

      if (!response.ok) {
        throw new Error(`OpenAI API error: ${response.status}`);
      }

      const data = await response.json();
      return data.choices[0].message.content;
      
    } catch (error) {
      console.error('OpenAI API error:', error);
      throw error;
    }
  }

  /**
   * Call Hugging Face API (free alternative)
   */
  async callHuggingFace(userMessage, systemPrompt) {
    try {
      const response = await fetch(
        'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium',
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            inputs: `${systemPrompt}\n\nUser: ${userMessage}\nAssistant:`
          })
        }
      );

      if (!response.ok) {
        throw new Error(`Hugging Face API error: ${response.status}`);
      }

      const data = await response.json();
      return data[0]?.generated_text?.split('Assistant:').pop()?.trim() || 'I apologize, but I\'m having trouble generating a response right now.';
      
    } catch (error) {
      console.error('Hugging Face API error:', error);
      throw error;
    }
  }

  /**
   * Call Google Gemini API (has free tier)
   */
  async callGemini(userMessage, systemPrompt) {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${this.apiKey}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            contents: [{
              parts: [{
                text: `${systemPrompt}\n\nUser: ${userMessage}`
              }]
            }]
          })
        }
      );

      if (!response.ok) {
        throw new Error(`Gemini API error: ${response.status}`);
      }

      const data = await response.json();
      return data.candidates[0]?.content?.parts[0]?.text || 'I apologize, but I\'m having trouble generating a response right now.';
      
    } catch (error) {
      console.error('Gemini API error:', error);
      throw error;
    }
  }

  /**
   * Check if AI service is available
   */
  isEnabled() {
    return this.enabled;
  }

  /**
   * Get supported providers
   */
  static getSupportedProviders() {
    return [
      { 
        id: 'openai', 
        name: 'OpenAI (GPT-3.5/GPT-4)', 
        cost: 'Paid', 
        quality: 'Excellent',
        setup: 'Requires OpenAI API key'
      },
      { 
        id: 'gemini', 
        name: 'Google Gemini', 
        cost: 'Free tier available', 
        quality: 'Very Good',
        setup: 'Requires Google API key'
      },
      { 
        id: 'huggingface', 
        name: 'Hugging Face', 
        cost: 'Free', 
        quality: 'Good',
        setup: 'Requires Hugging Face API key'
      }
    ];
  }
}

export default AIService;