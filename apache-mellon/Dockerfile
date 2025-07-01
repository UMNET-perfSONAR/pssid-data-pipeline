FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Apache (without mod_auth_mellon for now)
RUN apt-get update && apt-get install -y \
    apache2 \
    ssl-cert \
    && rm -rf /var/lib/apt/lists/*

# Enable required modules
RUN a2enmod ssl rewrite proxy proxy_http headers

# Create necessary directories
RUN mkdir -p /var/lock/apache2 /var/run/apache2

# Copy VirtualHost configuration
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf

# Enable the site
RUN a2ensite 000-default

# Expose ports
EXPOSE 80 443

# Start Apache in foreground
CMD ["apache2ctl", "-D", "FOREGROUND"]