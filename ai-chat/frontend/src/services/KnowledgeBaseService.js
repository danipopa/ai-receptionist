/**
 * Enhanced Knowledge Base Service
 * Combines website content, FAQs, and smart matching for better responses
 */

class KnowledgeBaseService {
  constructor() {
    this.websiteContent = new Map();
    this.faqs = [];
    this.commonQueries = new Map();
    this.businessInfo = {};
  }

  /**
   * Initialize knowledge base with website content and FAQs
   */
  async initialize(config = {}) {
    this.businessInfo = {
      name: config.businessName || 'Our Business',
      hours: config.businessHours || 'Monday-Friday, 9 AM to 5 PM EST',
      phone: config.phone || '',
      email: config.email || '',
      address: config.address || '',
      services: config.services || [],
      websiteUrl: config.websiteUrl || ''
    };

    // Load FAQs from backend
    if (config.faqs) {
      this.faqs = config.faqs;
    }

    // Pre-populate common business queries
    this.initializeCommonQueries();

    // If website URL provided, extract content
    if (config.websiteUrl) {
      await this.extractWebsiteContent(config.websiteUrl);
    }
  }

  /**
   * Extract and index website content
   */
  async extractWebsiteContent(websiteUrl) {
    try {
      // In a real implementation, you'd scrape the website
      // For now, we'll use common website sections
      this.websiteContent.set('about', {
        title: 'About Us',
        content: 'Information about our company, mission, and values.',
        keywords: ['about', 'company', 'mission', 'values', 'who we are']
      });

      this.websiteContent.set('services', {
        title: 'Our Services',
        content: this.businessInfo.services.join(', '),
        keywords: ['services', 'what we do', 'offerings', 'products']
      });

      this.websiteContent.set('contact', {
        title: 'Contact Information',
        content: `Phone: ${this.businessInfo.phone}, Email: ${this.businessInfo.email}, Address: ${this.businessInfo.address}`,
        keywords: ['contact', 'phone', 'email', 'address', 'location', 'reach us']
      });

      console.log('Website content indexed successfully');
    } catch (error) {
      console.error('Failed to extract website content:', error);
    }
  }

  /**
   * Initialize common business queries with smart responses
   */
  initializeCommonQueries() {
    this.commonQueries.set('hours', {
      patterns: ['hours', 'open', 'closed', 'when', 'time', 'schedule'],
      response: () => `Our business hours are ${this.businessInfo.hours}.`
    });

    this.commonQueries.set('contact', {
      patterns: ['contact', 'phone', 'call', 'email', 'reach'],
      response: () => {
        let contact = 'You can contact us ';
        if (this.businessInfo.phone) contact += `by phone at ${this.businessInfo.phone}, `;
        if (this.businessInfo.email) contact += `by email at ${this.businessInfo.email}, `;
        contact += 'or through this chat.';
        return contact;
      }
    });

    this.commonQueries.set('location', {
      patterns: ['location', 'address', 'where', 'find you', 'directions'],
      response: () => this.businessInfo.address 
        ? `We're located at ${this.businessInfo.address}.`
        : 'Please contact us for our location information.'
    });

    this.commonQueries.set('services', {
      patterns: ['services', 'what do you do', 'offerings', 'products', 'help with'],
      response: () => this.businessInfo.services.length > 0
        ? `We offer: ${this.businessInfo.services.join(', ')}. Would you like more details about any specific service?`
        : 'We offer various services. Please let me know what you\'re looking for and I can provide more specific information.'
    });

    this.commonQueries.set('pricing', {
      patterns: ['pricing', 'cost', 'price', 'how much', 'fees', 'rates'],
      response: () => 'For detailed pricing information, I\'d be happy to connect you with one of our representatives who can provide a customized quote based on your needs.'
    });

    this.commonQueries.set('help', {
      patterns: ['help', 'support', 'assistance', 'problem', 'issue'],
      response: () => 'I\'m here to help! You can ask me about our services, hours, contact information, or any other questions. If you need specialized assistance, I can connect you with a human agent.'
    });
  }

  /**
   * Enhanced response generation with context awareness
   */
  async generateResponse(userMessage, conversationHistory = []) {
    const message = userMessage.toLowerCase().trim();
    
    // 1. Try FAQ matching first (highest priority)
    const faqMatch = this.findBestFAQMatch(message);
    if (faqMatch) {
      return {
        response: faqMatch.answer,
        source: 'FAQ',
        confidence: faqMatch.confidence
      };
    }

    // 2. Try website content matching
    const websiteMatch = this.findWebsiteContentMatch(message);
    if (websiteMatch) {
      return {
        response: websiteMatch.content,
        source: 'Website',
        confidence: websiteMatch.confidence
      };
    }

    // 3. Try common query patterns
    const commonQueryMatch = this.findCommonQueryMatch(message);
    if (commonQueryMatch) {
      return {
        response: commonQueryMatch.response(),
        source: 'Business Info',
        confidence: commonQueryMatch.confidence
      };
    }

    // 4. Context-aware fallback
    const contextualResponse = this.generateContextualFallback(message, conversationHistory);
    return {
      response: contextualResponse,
      source: 'Contextual',
      confidence: 0.3
    };
  }

  /**
   * Enhanced FAQ matching with fuzzy search
   */
  findBestFAQMatch(message) {
    let bestMatch = null;
    let highestScore = 0;

    for (const faq of this.faqs) {
      const score = this.calculateSimilarity(message, faq.question.toLowerCase());
      
      // Also check if the message contains key terms from the FAQ
      const keyTerms = faq.question.toLowerCase().split(' ').filter(word => word.length > 3);
      const termMatches = keyTerms.filter(term => message.includes(term)).length;
      const termScore = termMatches / keyTerms.length;
      
      const totalScore = Math.max(score, termScore);
      
      if (totalScore > highestScore && totalScore > 0.3) {
        highestScore = totalScore;
        bestMatch = { ...faq, confidence: totalScore };
      }
    }

    return bestMatch;
  }

  /**
   * Find matching website content
   */
  findWebsiteContentMatch(message) {
    let bestMatch = null;
    let highestScore = 0;

    for (const [key, content] of this.websiteContent) {
      const keywordMatches = content.keywords.filter(keyword => 
        message.includes(keyword.toLowerCase())
      ).length;
      
      if (keywordMatches > 0) {
        const score = keywordMatches / content.keywords.length;
        if (score > highestScore) {
          highestScore = score;
          bestMatch = { ...content, confidence: score };
        }
      }
    }

    return bestMatch;
  }

  /**
   * Find matching common queries
   */
  findCommonQueryMatch(message) {
    let bestMatch = null;
    let highestScore = 0;

    for (const [key, query] of this.commonQueries) {
      const matches = query.patterns.filter(pattern => 
        message.includes(pattern.toLowerCase())
      ).length;
      
      if (matches > 0) {
        const score = matches / query.patterns.length;
        if (score > highestScore) {
          highestScore = score;
          bestMatch = { ...query, confidence: score };
        }
      }
    }

    return bestMatch;
  }

  /**
   * Calculate text similarity (simple implementation)
   */
  calculateSimilarity(text1, text2) {
    const words1 = new Set(text1.split(' '));
    const words2 = new Set(text2.split(' '));
    const intersection = new Set([...words1].filter(x => words2.has(x)));
    const union = new Set([...words1, ...words2]);
    return intersection.size / union.size;
  }

  /**
   * Generate contextual fallback response
   */
  generateContextualFallback(message, conversationHistory) {
    // Analyze conversation history for context
    const hasAskedAboutServices = conversationHistory.some(msg => 
      msg.text && msg.text.toLowerCase().includes('service')
    );
    
    const hasAskedAboutPricing = conversationHistory.some(msg => 
      msg.text && msg.text.toLowerCase().includes('price')
    );

    // Generate contextual response
    if (hasAskedAboutServices) {
      return `I understand you're interested in our services. Based on your question about "${message}", I'd recommend speaking with one of our specialists who can provide detailed information tailored to your needs. Would you like me to connect you?`;
    }

    if (hasAskedAboutPricing) {
      return `For specific pricing related to "${message}", I can connect you with our sales team who can provide accurate quotes and discuss options that fit your budget.`;
    }

    // Default intelligent fallback
    return `I understand you're asking about "${message}". While I search our knowledge base for more specific information, would you like me to connect you with one of our team members who can provide expert assistance?`;
  }

  /**
   * Add new FAQ dynamically
   */
  addFAQ(question, answer, category = 'general') {
    this.faqs.push({
      id: Date.now(),
      question,
      answer,
      category,
      created_at: new Date().toISOString()
    });
  }

  /**
   * Update business information
   */
  updateBusinessInfo(info) {
    this.businessInfo = { ...this.businessInfo, ...info };
    this.initializeCommonQueries(); // Refresh common queries with new info
  }
}

export default KnowledgeBaseService;