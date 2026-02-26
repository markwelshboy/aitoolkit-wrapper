FROM ostris/aitoolkit:latest

COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

COPY prestart.sh /usr/local/bin/prestart.sh
RUN chmod +x /usr/local/bin/prestart.sh

ENTRYPOINT ["/usr/local/bin/prestart.sh"]
