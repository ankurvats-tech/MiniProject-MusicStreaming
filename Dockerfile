# Use Node.js LTS version
FROM node:18

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy rest of the project
COPY . .

# Expose port
EXPOSE 3000

# Start the app
CMD ["npm", "start"]
