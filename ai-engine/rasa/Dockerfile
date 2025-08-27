FROM rasa/rasa:3.6.13-full

WORKDIR /app

COPY . /app

# Install any additional dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Train the model
RUN rasa train

# Expose the port
EXPOSE 5005

# Run Rasa
CMD ["rasa", "run", "--enable-api", "--cors", "*", "--debug"]
