FROM ruby:2.5.1

RUN bundle config --global frozen 1

WORKDIR /opt/app
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
ENV RACK_ENV production
CMD ["bundle", "exec", "rackup", "-p", "3000", "-o", "0.0.0.0"]
