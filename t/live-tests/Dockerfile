#!/usr/local/bin/perl

# Use the official Perl image (comes with compilation tools and cpanm)
FROM perl:5.40

# Install Apache2 and mod_perl / CGI support
RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-perl2 \
    make \
    gcc \
    libc6-dev \
    libmoose-perl \
    && rm -rf /var/lib/apt/lists/*

# Enable CGI module in Apache config
RUN a2enmod cgid

# Pre-install your SDK's heavy dependencies to speed up future runs.
# Use --notest because running S3 test suites during a Docker build takes forever.
RUN /usr/bin/perl /usr/local/bin/cpanm --notest \
    Net::Amazon::S3 \
    JSON \
    HTTP::Tiny \
    CGI \
    Moose \
    Digest::SHA

# Tell Apache to pass your custom environment variables to CGI scripts
RUN echo "PassEnv ACCESS_KEY_ID" >> /etc/apache2/apache2.conf \
    && echo "PassEnv SECRET_ACCESS_KEY" >> /etc/apache2/apache2.conf \
    && echo "PassEnv PIPELINE_SHARED_SECRET" >> /etc/apache2/apache2.conf

ENV PERL5LIB=/usr/local/share/perl/lib:/usr/local/lib/perl5/site_perl/5.40.4
RUN echo "PassEnv PERL5LIB" >> /etc/apache2/apache2.conf

# Pass the correct 5.40.4 site_perl path to Apache's CGI daemon
RUN echo "SetEnv PERL5LIB /usr/local/share/perl/lib:/usr/local/lib/perl5/site_perl/5.40.4" >> /etc/apache2/apache2.conf

# Keep the ServerName fix to suppress the warning log
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Copy and install dependencies
COPY cpanfile .
RUN cpanm --notest --installdeps .

RUN chmod -R o+rx /usr/local/lib/perl5/site_perl/

# Configure Apache to foreground execute (so Docker can manage it)
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_PID_FILE=/var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR=/var/run/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2

RUN mkdir -p $APACHE_RUN_DIR $APACHE_LOCK_DIR $APACHE_LOG_DIR

# Create directories and link logs to console stdout/stderr
RUN mkdir -p $APACHE_RUN_DIR $APACHE_LOCK_DIR $APACHE_LOG_DIR \
    && ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

# Expose HTTP port
EXPOSE 80

# Start Apache in the foreground
CMD ["/usr/sbin/apache2", "-D", "FOREGROUND"]
