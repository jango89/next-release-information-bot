## Notify Release

This bot will help to notify next release version, current version information and hosts running the current version. 
Next release information for a service will help us to do rollback, monitor etc in one click when all the related information 
are available handy.

## Why

1. Displays current running version from `admin/info` endpoint. Easy to know rollback-version in-case needed.
2. Displays which machines we need to deploy, based on current running instances.
3. Displays all the latest artifacts available to release.
4. Link to open the splunk for continous monitoring.
5. All the information on one google chat thread.

### Usages

```./next_release.sh commons-affiliate-management```
```./next_release.sh brokerage-webapp {version_no}```. Display this version as to be next version instead of fetching from artifactory.

### FYI
1. Please update environment variables in `environment.sh` before using
