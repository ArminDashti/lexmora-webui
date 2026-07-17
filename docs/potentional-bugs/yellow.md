# Minor risks / code smells

- **[Auth]** Client only checks token presence in localStorage; expired JWTs still pass the router guard until the next API call returns 401.
- **[Stats]** If an older API without `compare` in `StatsBucket` is used, the Compare column shows `undefined`.
