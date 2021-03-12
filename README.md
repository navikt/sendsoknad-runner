# GitHub runner for Melosys API

Dette prosjektet er et støtteverktøy for [melosys-api](https://github.com/navikt/melosys-api); en såkalt
[self-hosted runner](https://docs.github.com/en/free-pro-team@latest/actions/hosting-your-own-runners/about-self-hosted-runners)
for å deploye applikasjonen fra GitHub Actions med tilgang til interne ressurser. Behovet for en self-hosted runner 
skyldes først og fremst Maven-avhengigheter fra intern Nexus (https://repo.adeo.no), hvorav noen få er under aktiv
utvikling, og ikke kan nås fra utsiden.

Default Java-versjon for runneren er Java 11, men Java 15 er også installert og kan benyttes ved å sette `JAVA_HOME`:

```
JAVA_HOME=/usr/local/openjdk-15 mvn package
```

## Miljø

Applikasjonen bruker et baseimage med Java og Maven for bygging av `melosys-api`, samt komponenter fra
[navikt/baseimages](https://github.com/navikt/baseimages/), for et "NAIS native" oppsett med bl.a. automatisk
eksportering av miljøvariabler fra Vault.

For autentisering mot GitHub API, brukes en GitHub App, [Melosys Runnner](https://github.com/apps/melosys-runner/),
som er lagt til `melosys-api`-repoet. Denne appen har rettigheten `administration:write` for å kunne kalle
`POST /repos/:owner/:repo/actions/runners/registration-token`, i henhold til 
[dokumentasjonen](https://docs.github.com/en/free-pro-team@latest/rest/reference/permissions-required-for-github-apps#permission-on-administration),
og bruker `APP_ID` og `melosys-runner.pem` fra Vault til autentisering.

## Utvikling

Det er mulig å bygge og kjøre et Docker-image for testing lokalt ved å oppgi et
[personal access token](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token) 
(PAT) med `repo`-scope som `--build-arg`:

```
docker build --build-arg GITHUB_TOKEN=[GitHub PAT] -t melosys-api-runner .
docker run melosys-api-runner
```

Det er i tillegg hensiktsmessig å endre labels som beskriver runneren (`RUNNER_LABELS` i `Dockerfile`), slik at man
kan velge lokalt kjørende runner i en workflow for `melosys-api`, f.eks.:

```
runs-on: [self-hosted, utvikling]
```

## Gjenbruk

En begrensning ved self-hosted runners er at de kun kan settes opp på repo- eller org-nivå, og det er derfor ikke mulig å
bruke denne runneren til andre repo i teamet. Ved eventuelt behov for gjenbruk i andre repo (f.eks. automatisert testing
i miljø), vil det enkleste sannsynligvis være å forke til et nytt repo, og gjøre nødvendige tilpasninger. GitHub App-en,
[Melosys Runnner](https://github.com/apps/melosys-runner/), som benyttes til autentisering mot API-et må legges til nye
repo-er som skal benytte runneren, noe det kan være nødvendig å be en navikt owner om å gjøre. I tillegg vil det være
hensiktsmessig å endre deployment spec-en til å benytte en team secret for `APP_ID` og `melosys-runner.pem`, for å
slippe å duplisere disse mellom ulike runner-applikasjoner.

## Kilder

Store deler av `Dockerfile` og `run-script.sh` er hentet fra [SanderKnape/github-runner](https://github.com/SanderKnape/github-runner),
som er tilgjengelig under [MIT-lisensen](https://github.com/SanderKnape/github-runner/blob/master/LICENSE.md).