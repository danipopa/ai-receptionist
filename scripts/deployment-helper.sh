#!/bin/bash

# AI Receptionist Deployment Decision Helper
# Interactive guide to choose the best deployment option

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
    _    ___   ____                      _   _             _     _   
   / \  |_ _| |  _ \ ___  ___ ___ _ __   | |_(_) ___  _ __ (_)___| |_ 
  / _ \  | |  | |_) / _ \/ __/ _ \ '_ \  | __| |/ _ \| '_ \| / __| __|
 / ___ \ | |  |  _ <  __/ (_|  __/ |_) | | |_| | (_) | | | | \__ \ |_
/_/   \_\___| |_| \_\___|\___\___| .__/   \__|_|\___/|_| |_|_|___/\__|
                                 |_|                                 
EOF
echo -e "${NC}"

echo -e "${BLUE}🚀 Deployment Decision Helper${NC}"
echo "=============================="
echo ""

# Questions and scoring
score_azure=0
score_onprem=0
score_hybrid=0

echo -e "${YELLOW}Please answer the following questions to get personalized recommendations:${NC}"
echo ""

# Question 1: Organization size
echo "1. What's your organization size?"
echo "   a) Small business (1-50 employees)"
echo "   b) Medium business (50-500 employees)"  
echo "   c) Large enterprise (500+ employees)"
read -p "Your choice (a/b/c): " q1

case $q1 in
    a) score_azure=$((score_azure + 3)); score_onprem=$((score_onprem + 1));;
    b) score_azure=$((score_azure + 2)); score_onprem=$((score_onprem + 2)); score_hybrid=$((score_hybrid + 3));;
    c) score_onprem=$((score_onprem + 3)); score_hybrid=$((score_hybrid + 2));;
esac

# Question 2: Expected call volume
echo ""
echo "2. Expected peak concurrent calls?"
echo "   a) 1-10 calls"
echo "   b) 10-50 calls"
echo "   c) 50+ calls"
read -p "Your choice (a/b/c): " q2

case $q2 in
    a) score_azure=$((score_azure + 3)); score_onprem=$((score_onprem + 2));;
    b) score_azure=$((score_azure + 2)); score_onprem=$((score_onprem + 3)); score_hybrid=$((score_hybrid + 2));;
    c) score_onprem=$((score_onprem + 3)); score_hybrid=$((score_hybrid + 3));;
esac

# Question 3: Technical expertise
echo ""
echo "3. Your team's technical expertise?"
echo "   a) Limited (prefer managed services)"
echo "   b) Moderate (can manage basic infrastructure)"
echo "   c) Advanced (full DevOps capabilities)"
read -p "Your choice (a/b/c): " q3

case $q3 in
    a) score_azure=$((score_azure + 3));;
    b) score_azure=$((score_azure + 2)); score_hybrid=$((score_hybrid + 2));;
    c) score_onprem=$((score_onprem + 3)); score_hybrid=$((score_hybrid + 1));;
esac

# Question 4: Budget priority
echo ""
echo "4. Budget priority?"
echo "   a) Minimize upfront costs"
echo "   b) Balance upfront and operational costs"
echo "   c) Minimize long-term operational costs"
read -p "Your choice (a/b/c): " q4

case $q4 in
    a) score_azure=$((score_azure + 3));;
    b) score_hybrid=$((score_hybrid + 3));;
    c) score_onprem=$((score_onprem + 3));;
esac

# Question 5: Data sensitivity
echo ""
echo "5. Data sensitivity requirements?"
echo "   a) Standard business data"
echo "   b) Sensitive customer data"
echo "   c) Highly regulated (healthcare, finance, government)"
read -p "Your choice (a/b/c): " q5

case $q5 in
    a) score_azure=$((score_azure + 2)); score_hybrid=$((score_hybrid + 1));;
    b) score_onprem=$((score_onprem + 2)); score_hybrid=$((score_hybrid + 3));;
    c) score_onprem=$((score_onprem + 3));;
esac

# Question 6: Scalability needs
echo ""
echo "6. Scalability requirements?"
echo "   a) Steady, predictable load"
echo "   b) Seasonal variations"
echo "   c) Highly variable, rapid scaling needed"
read -p "Your choice (a/b/c): " q6

case $q6 in
    a) score_onprem=$((score_onprem + 2));;
    b) score_hybrid=$((score_hybrid + 3));;
    c) score_azure=$((score_azure + 3));;
esac

# Question 7: Geographic distribution
echo ""
echo "7. Geographic distribution?"
echo "   a) Single location"
echo "   b) Multiple locations in same country"
echo "   c) Global presence"
read -p "Your choice (a/b/c): " q7

case $q7 in
    a) score_onprem=$((score_onprem + 2));;
    b) score_hybrid=$((score_hybrid + 3));;
    c) score_azure=$((score_azure + 3));;
esac

# Calculate results
echo ""
echo -e "${PURPLE}🧮 Calculating your recommendation...${NC}"
sleep 2

echo ""
echo -e "${GREEN}📊 RESULTS${NC}"
echo "=========="
echo ""

# Determine winner
if [ $score_azure -ge $score_onprem ] && [ $score_azure -ge $score_hybrid ]; then
    winner="Azure Cloud"
    winner_color=$BLUE
elif [ $score_onprem -ge $score_azure ] && [ $score_onprem -ge $score_hybrid ]; then
    winner="On-Premises"
    winner_color=$GREEN
else
    winner="Hybrid"
    winner_color=$YELLOW
fi

echo -e "${winner_color}🏆 RECOMMENDED: $winner${NC}"
echo ""

echo "Compatibility Scores:"
echo -e "  ${BLUE}Azure Cloud:${NC}    $score_azure/21 points"
echo -e "  ${GREEN}On-Premises:${NC}   $score_onprem/21 points"
echo -e "  ${YELLOW}Hybrid:${NC}        $score_hybrid/21 points"
echo ""

# Detailed recommendations
echo -e "${CYAN}📋 Detailed Analysis:${NC}"
echo ""

if [ "$winner" = "Azure Cloud" ]; then
    echo -e "${BLUE}☁️  AZURE CLOUD DEPLOYMENT${NC}"
    echo "✅ Best for your needs because:"
    echo "   • Lower upfront costs"
    echo "   • Managed infrastructure"
    echo "   • Easy scaling"
    echo "   • Global availability"
    echo ""
    echo "💰 Estimated monthly cost: $1,500-3,000"
    echo "⚡ Deployment time: 2-4 hours"
    echo "🔧 Maintenance: Minimal"
    echo ""
    echo "🚀 Quick start command:"
    echo "   ./scripts/deploy-azure-aks.sh"
    
elif [ "$winner" = "On-Premises" ]; then
    echo -e "${GREEN}🏢 ON-PREMISES DEPLOYMENT${NC}"
    echo "✅ Best for your needs because:"
    echo "   • Full data control"
    echo "   • Lower long-term costs"
    echo "   • High performance"
    echo "   • Complete customization"
    echo ""
    echo "💰 Estimated setup cost: $4,000-40,000"
    echo "💰 Monthly operational: $150-2,700"
    echo "⚡ Deployment time: 1-3 days"
    echo "🔧 Maintenance: Regular required"
    echo ""
    echo "📖 Setup guide:"
    echo "   docs/deployment/ON-PREMISES-GUIDE.md"
    
else
    echo -e "${YELLOW}🌐 HYBRID DEPLOYMENT${NC}"
    echo "✅ Best for your needs because:"
    echo "   • Balanced approach"
    echo "   • Data flexibility"
    echo "   • Cost optimization"
    echo "   • Risk distribution"
    echo ""
    echo "💰 Estimated cost: Variable"
    echo "⚡ Deployment time: 1-2 days"
    echo "🔧 Maintenance: Moderate"
    echo ""
    echo "🏗️ Architecture:"
    echo "   • Core services on-premises"
    echo "   • Scaling to cloud"
    echo "   • Data residency compliance"
fi

echo ""
echo -e "${PURPLE}📞 Need help deciding?${NC}"
echo "Book a consultation: https://calendly.com/ai-receptionist"
echo ""
echo -e "${CYAN}🔄 Run again?${NC}"
read -p "Run the assessment again? (y/N): " run_again

if [[ $run_again =~ ^[Yy]$ ]]; then
    echo ""
    exec "$0"
fi

echo ""
echo -e "${GREEN}Thank you for using the AI Receptionist Deployment Helper!${NC}"
