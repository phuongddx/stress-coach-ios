# Custom product pages

Each JSON file describes one custom product page: its name, promotional text and
screenshot order. Screenshot paths point at the 1.1.0 sets in `metadata/screenshots/1.1.0/`,
so the images are stored once.

The pages exist in App Store Connect as drafts only. They are not submitted for review.
Create or refresh a page with the asc CLI:

```sh
asc product-pages custom-pages create --app 6778478266 --name "Apple Watch"
asc product-pages custom-pages localizations update --localization-id <ID> --promotional-text "..."
asc product-pages custom-pages localizations screenshot-sets upload --localization-id <ID> --path <ordered dir> --device-type IPHONE_67
```

Upload a set from a folder whose file names follow the order in the JSON file
(for example `01-…png`, `02-…png`).

Apple only accepts iPhone and iPad screenshot sets on custom product pages. Watch
screenshots are rejected with "Display Type Not Allowed", so these pages use the iPhone set only.
