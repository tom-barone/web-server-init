# Update graphite

Update a dokku hosted [graphite](https://github.com/dokku/dokku-graphite) instance on a production server to a later version.

Remove the old service:

```bash
# List all existing graphite services (there should be just one called 'graphite')
dokku graphite:list
# Print all existing links to the service
dokku graphite:links graphite

# Run this for all links to the service
dokku ps:stop <app>
dokku graphite:unlink graphite <app>

# Remove the service
dokku graphite:destroy graphite
```

Start the new graphite service and expose the correct ports. Take a look at the `init.sh` script for how to do this.

Relink the apps to the new service:

```bash
dokku graphite:link graphite <app>
dokku ps:restart <app>
```