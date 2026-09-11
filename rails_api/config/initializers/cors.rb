# Be sure to restart your server when you modify this file.

# The native desktop build doesn't go through a browser, so CORS never applies to it.
# This only exists so the Flutter app can also be run with `flutter run -d chrome`
# during development, where the dev server uses a random localhost port.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins %r{\Ahttp://(localhost|127\.0\.0\.1)(:\d+)?\z}

    resource "*",
      headers: :any,
      methods: [ :get, :post, :options, :head ]
  end
end
