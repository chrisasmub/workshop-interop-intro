Sample Angular web application used by this workshop to exercise InterSystems IRIS APIs locally.

# Overview

The web app is served through Docker at:

- `http://localhost:8080`

After login, it currently exposes these main routes:

- `/guide` for the workshop walkthrough
- `/loan` for the step-by-step `Loan Lab`
- `/create-order` for the order entry demo

Login uses the local IRIS JWT flow. In the workshop setup, the usual credentials are:

- Username: `superuser`
- Password: `SYS`

# Development

This project was generated with Angular CLI `19.1.0`.

## Prerequisites

- Node.js
- npm

## Install dependencies

```bash
npm install
```

## Run locally in dev mode

```bash
ng serve
```

Then open:

- `http://localhost:4200`

# Production build

To build the Angular app directly:

```bash
npm run build:production
```

To rebuild the container used by the workshop:

```bash
docker compose build webapp
docker compose up -d webapp
```

# Loan Lab

The `Loan Lab` page is a guided frontend for the `Demo.Loan` production. It can:

- check which production is currently running
- switch automatically to `Demo.Loan.FindRateProduction`
- call the simulated `Prime Rate` operation
- call the simulated `Credit Rating` operation
- submit a full loan application
- show the aggregated decision, bank-by-bank responses, and trace links

The Angular page uses these backend endpoints exposed by `Demo.Order.BS.OrderAPI`:

- `GET /order/api/loan/production/status`
- `POST /order/api/loan/production/prepare`
- `POST /order/api/loan/prime-rate`
- `POST /order/api/loan/credit-rating`
- `POST /order/api/loan/application`

# Notes

- If you change Angular source files, rebuild the `webapp` container to see the production version on port `8080`
- The Loan flow is easiest to test from `/loan`, but there is also a CSP version at `http://localhost:52774/csp/interop/DemoLoanLab.csp`
- The socket callback part of the Loan demo still expects a TCP listener on port `4321`; if none exists, the IRIS TCP operation will log timeout errors
