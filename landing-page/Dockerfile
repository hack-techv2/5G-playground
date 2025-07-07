FROM nginx:alpine

# Copy all website files to nginx html directory
COPY . /usr/share/nginx/html

# Ensure challenge-files directory exists and has proper permissions
RUN mkdir -p /usr/share/nginx/html/challenge-files && \
    chmod 755 /usr/share/nginx/html/challenge-files

# Copy custom nginx configuration if needed
# COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 