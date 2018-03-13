## Kohadev README

This Docker image builds on a Koha docker image `digibib/koha:$TAG` from Dockerhub and
includes a complete Koha development install setup from git source.

It is very simple to setup and ready for use.

It is also preinstalled with git-bz tools to patch from bugzilla and qa-tools for testing

Documentation can be found on project [wiki](https://github.com/digibib/koha-docker/wiki)

## Elasticsearch in Koha (WIP)

koha_dev now supports elasticsearch (WIP)

an elasticsearch container can be spun up with

```
cd docker-compose && \
source docker-compose.env && docker-compose -f common.yml -f es.yml run --rm --publish=9200:9200 koha_es
```

This will pull elasticsearch 5.6.8 and setup two data volumes (koha_esplugins, koha_esdata)

## Manual steps

* neccessary plugins

```
docker exec -it dockercompose_koha_es_run_1 bin/elasticsearch-plugin list
docker exec -it dockercompose_koha_es_run_1 bin/elasticsearch-plugin install analysis-icu
```

# Reset koha mapping tables

basically resets and populates tables search_field, search_marc_map, search_marc_to_field from

./admin/searchengine/elasticsearch/mappings.yaml


```
localhost:8081/cgi-bin/koha/admin/searchengine/elasticsearch/mappings.pl?op=reset&i_know_what_i_am_doing=1
```

# Rebuild index

KOHA_CONF=/etc/koha/sites/name/koha-conf.xml PERL5LIB=/kohadev/kohaclone ./misc/search_tools/rebuild_elastic_search.pl --verbose --delete
