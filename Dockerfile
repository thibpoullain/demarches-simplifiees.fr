FROM ruby:3.2.2

# ARG port

# environment variables
# ENV PORT $port

RUN sed -i 's#http:#https:#g' /etc/apt/sources.list
RUN apt update && apt install -y libcurl3-dev libpq-dev zlib1g-dev libssl-dev libreadline-dev zlib1g-dev zip

# Add node for webpack
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN apt-get update; apt-get install -y yarn

# Chromedriver
RUN curl -fsSL https://chromedriver.storage.googleapis.com/91.0.4472.19/chromedriver_linux64.zip | gunzip > /usr/bin/chromedriver && chmod +x /usr/bin/chromedriver
RUN sh -c 'echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN apt-get update && apt-get install -y google-chrome-stable

RUN mkdir /opt/ds
WORKDIR /opt/ds

RUN useradd -ms /bin/bash demat-social

# Copie de ces fichiers de manière à ce que les gems / nodes ne soient pas toujours retéléchargées
COPY package.json /opt/ds
COPY yarn.lock /opt/ds
COPY Gemfile /opt/ds
COPY Gemfile.lock /opt/ds
COPY config/vite.json /opt/ds/config/vite.json

RUN mkdir /usr/local/bundle/gems && \
    mkdir node_modules && \
    mkdir tmp && \
    mkdir log && touch log/development.log

RUN bundle config path /usr/local/bundle/cache && \
    bundle config cache_path /usr/local/bundle/cache

RUN bundle install --jobs 20 --retry 5
RUN yarn install

# app port 3000
# vite port 3036 (default 3036, will be changed to 5173 in later versions of Vite)
EXPOSE $PORT

CMD ["/bin/bash", "-c", "bin/rails s -b 0.0.0.0 -p $PORT"]
