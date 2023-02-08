  The `Ingress` resource in this directory will set up a single external hostname route to your application's Nginx Pod. The Nginx config is set up to handle proxying the application as well as the static files associated with a Django app. If you are using Flask or another framework, you may need to adjust your app configuration or Nginx config paths.
  
 For custom domains, set up secret(s) under bases/components/tls and uncomment the `tls` section in `Ingress`.
