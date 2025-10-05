import React from 'react';

const FAQSuggestions = ({ faqs, onSelectFAQ, onClose }) => {
  if (!faqs || faqs.length === 0) {
    return (
      <div className="faq-container">
        <div className="faq-header">
          <h3 className="faq-title">Frequently Asked Questions</h3>
          <button className="faq-close-btn" onClick={onClose}>✕</button>
        </div>
        <div className="faq-content">
          <p className="no-faqs">No FAQs available at the moment.</p>
        </div>
      </div>
    );
  }

  // Sort FAQs by priority and limit to top 10
  const sortedFAQs = faqs
    .sort((a, b) => (a.priority || 999) - (b.priority || 999))
    .slice(0, 10);

  return (
    <div className="faq-container">
      <div className="faq-header">
        <h3 className="faq-title">Frequently Asked Questions</h3>
        <button className="faq-close-btn" onClick={onClose}>✕</button>
      </div>
      <div className="faq-content">
        <div className="faq-list">
          {sortedFAQs.map((faq) => (
            <div
              key={faq.id}
              className="faq-item"
              onClick={() => onSelectFAQ(faq)}
            >
              <div className="faq-question">{faq.question}</div>
              {faq.category && (
                <div className="faq-category">{faq.category}</div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default FAQSuggestions;