# 🚀 Workshop: Introduction to InterSystems IRIS Interoperability

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE) [![Docker Ready](https://img.shields.io/badge/docker-ready-blue)](https://www.docker.com/) [![VS Code Compatible](https://img.shields.io/badge/VS%20Code-Compatible-blueviolet)](https://code.visualstudio.com/) [![Maintained](https://img.shields.io/badge/status-maintained-brightgreen)](#) [![InterSystems IRIS](https://img.shields.io/badge/Powered%20by-InterSystems%20IRIS-ff69b4)](https://www.intersystems.com/iris)

Welcome! This repository contains a set of hands-on examples to help you understand the key concepts of the **InterSystems IRIS Interoperability Framework**.

> For more in-depth learning resources, visit [InterSystems Learning](https://learning.intersystems.com).

> If you are interested in 🏥 HealthCare interoperability, visit [workshop-healthcare-interop](https://github.com/intersystems-ib/workshop-healthcare-interop)

---

## 🧰 Requirements

To run this workshop, please make sure you have the following installed:

- [Git](https://git-scm.com/downloads)  
- [Docker](https://www.docker.com/products/docker-desktop) and [Docker Compose](https://docs.docker.com/compose/install/) - ⚠️ On Windows, ensure Docker is set to use **Linux containers**.  
- [Visual Studio Code](https://code.visualstudio.com/download) with [InterSystems ObjectScript Extension Pack](https://marketplace.visualstudio.com/items?itemName=intersystems-community.objectscript-pack)

---

## ⚙️ Setup

Clone the repository and start the project using Docker Compose:

```bash
git clone https://github.com/intersystems-ib/workshop-interop-intro
cd workshop-interop-intro
docker compose build
docker compose up -d
```

Then, open the `workshop-interop-intro` folder in **VS Code**.

### Local Port Mapping

In this local setup, IRIS was remapped to avoid conflicts with another running container:

- **IRIS superserver:** `localhost:11972`
- **IRIS web / portal:** `http://localhost:52774`
- **Sample web app:** `http://localhost:8080`

If you already use `1972` or `52773` in another project, keep using the ports above for this workshop.

---

## 📌 Current Status

Status documented on **April 2, 2026** after validating the project locally with Docker.

### ✅ What Is Working

- `docker compose build` and `docker compose up -d` complete successfully
- IRIS, MySQL, and the Angular sample web app start correctly
- The IRIS portal is available at [http://localhost:52774/csp/sys/UtilHome.csp](http://localhost:52774/csp/sys/UtilHome.csp)
- The Loan demo can now be exercised end to end from:
  - the Angular page at [http://localhost:8080/loan](http://localhost:8080/loan)
  - the self-contained CSP page at [http://localhost:52774/csp/interop/DemoLoanLab.csp](http://localhost:52774/csp/interop/DemoLoanLab.csp)
- The Order backend flow now completes through:
  - `Order API In`
  - `Order Process`
  - `Customer MySQL Query`
  - `Notification API Out`
- `POST /order/api/order` validates required fields and rejects invalid payloads with `400 Bad Request`
- `GET /order/api/orders` returns recent orders so the demo can show results without depending only on the portal
- The login flow for the sample web app now matches IRIS JWT auth using the local IRIS credentials
- The Loan file service input path `/Practice/loan/in` exists and is ready for local file-drop tests

### 🔧 Changes Applied During This Sprint

- Remapped IRIS ports from `1972/52773` to `11972/52774` to avoid collision with another local IRIS container
- Updated URLs in the README, Postman collection, web app environment files, and WSDL
- Added `Order API In` directly to `Demo.Order.Production` so the REST service is registered when the production starts
- Extended `Demo.Order.BS.OrderAPI` with helper endpoints for the Loan demo:
  - `GET /order/api/loan/production/status`
  - `POST /order/api/loan/production/prepare`
  - `POST /order/api/loan/prime-rate`
  - `POST /order/api/loan/credit-rating`
  - `POST /order/api/loan/application`
- Added a self-contained CSP page `DemoLoanLab.csp` for step-by-step Loan testing inside IRIS
- Added an Angular `Loan Lab` page and navigation entry in the sample web app
- Added `Practice/loan/in/.gitkeep` so the file-based Loan flow works in a clean checkout
- Normalized the Loan Lab UI text to ASCII-safe strings to avoid mojibake in CSP and Angular builds
- Updated the `JavaGateway` host to use an External Language Server (`%Java Server`), which is required in this IRIS version
- Configured `%Java Server` to load the MySQL JDBC jar during IRIS setup
- Replaced the fragile SQL response mapping with a custom business operation that returns a deterministic `Demo.Order.Msg.CustomerInfo`
- Corrected `Demo.Order.Msg.CustomerInfo` so it extends `Ens.Response`
- Set `ParamSQLTypes` for the MySQL lookup to `SQL_INTEGER`
- Added validation to `POST /order/api/order` so invalid requests no longer return a false-positive `201`
- Added a didactic `GET /order/api/orders` endpoint for recent order lookup
- Added readable BPL trace messages in `Order Process` to make the flow easier to explain live

### 🔎 Backend Endpoints

- `POST /order/api/order`
  - Valid payload: returns `201 Created`
  - Invalid payload: returns `400 Bad Request`
- `GET /order/api/orders`
  - Returns recent orders created through the REST entrypoint
- `POST /order/api/login`
  - Uses IRIS credentials via `Basic Auth`
  - Returns `access_token` and `refresh_token`
- `POST /order/api/refresh`
  - Uses the `refresh_token` in the JSON body
- `POST /order/api/logout`
  - Uses `Authorization: Bearer <access_token>`
- `GET /order/api/loan/production/status`
  - Returns the running production and whether it matches `Demo.Loan.FindRateProduction`
- `POST /order/api/loan/production/prepare`
  - Stops the current production if needed and starts `Demo.Loan.FindRateProduction`
- `POST /order/api/loan/prime-rate`
  - Returns the simulated prime rate from `Demo.Loan.WebOperations`
- `POST /order/api/loan/credit-rating`
  - Returns the deterministic credit rating for a given `taxId`
- `POST /order/api/loan/application`
  - Runs a full Loan request and returns the consolidated decision, bank replies, and trace links

### Quick API Checks

Start the production `Demo.Order.Production`, then try these:

1. Invalid request should fail cleanly:

```bash
curl -i -X POST http://localhost:52774/order/api/order \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected result:

- `400 Bad Request`
- JSON summary with the missing fields

2. Valid request should enter the production:

```bash
curl -i -X POST http://localhost:52774/order/api/order \
  -H "Content-Type: application/json" \
  -d '{
    "OrderPriority": "High",
    "Discount": "0.1",
    "UnitPrice": "205.99",
    "ShippingCost": "2.5",
    "CustomerID": "3",
    "ShipMode": "Express Air",
    "ProductCategory": "Technology",
    "ProductSubCategory": "Telephones and Communication",
    "ProductContainer": "Small Box",
    "ProductName": "V70",
    "OrderDate": "7/27/2011",
    "Quantity": "8",
    "Sales": "1446.67",
    "OrderID": "99004"
}'
```

Expected result:

- `201 Created`
- The message flows through the production

3. List recent orders:

```bash
curl -s http://localhost:52774/order/api/orders
```

4. Request JWT tokens with local IRIS credentials:

```bash
curl -i -u superuser:SYS \
  -X POST http://localhost:52774/order/api/login \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## 🎬 Simple Demo

This is the easiest and clearest way to explain the interoperability flow live.

### Goal

Show that the same business process:

- validates incoming data
- enriches the order with data from MySQL
- transforms the message for a downstream API
- keeps a visible trace of every step

### Before You Start

1. Run:

```bash
docker compose build
docker compose up -d
```

2. Open the IRIS portal:
   [http://localhost:52774/csp/sys/UtilHome.csp](http://localhost:52774/csp/sys/UtilHome.csp)

3. Login with:
   - Username: `superuser`
   - Password: `SYS`

4. Start the production:
   - Go to `Interoperability > Configure > Production`
   - Open `Demo.Order.Production`
   - Click `Start`

### Demo Script

1. Explain the architecture in one sentence:
   `REST request -> Order API In -> Order Process -> MySQL lookup -> Notification`

2. Show a bad request first:
   - Send `POST /order/api/order` with `{}`
   - Explain that interoperability starts by validating contracts, not by accepting everything

3. Show a valid request:
   - Send the sample order with `CustomerID = 3`
   - Explain that the order is accepted and routed into the production

4. Open the Message Viewer:
   [http://localhost:52774/csp/interop/EnsPortal.MessageViewer.zen](http://localhost:52774/csp/interop/EnsPortal.MessageViewer.zen)

5. Walk through the latest session in order:
   - `Order API In`
   - `Order Process`
   - `Customer MySQL Query`
   - `Notification API Out`

6. Open the Visual Trace for the session and point out the trace messages:
   - `order received`
   - `customer enriched`
   - `notification payload prepared`
   - `notification queued`

7. Show the created orders with:

```bash
curl -s http://localhost:52774/order/api/orders
```

8. Close with the key message:
   - One business flow
   - Multiple integration steps
   - Full traceability inside IRIS

### Very Short Version

If you only have 3 minutes:

1. Start `Demo.Order.Production`
2. Send one invalid request and show the `400`
3. Send one valid request and show the `201`
4. Open the Message Viewer and Visual Trace
5. Run `GET /order/api/orders`

### Optional Frontend Demo

If you also want to show the Angular app:

- Login now uses the local IRIS credentials
- Default credentials in the form are `superuser / SYS`
- The order form is preloaded with a stable sample order tied to `CustomerID = 3`

---

## 📂 Examples

### 1. 💰 Loan Request Flow: Talk to Multiple Banks

In this scenario, the system receives a loan request, queries multiple simulated banks, and aggregates the best available offer.

### Recommended Demo Paths

You can now exercise the Loan flow in three practical ways:

1. Angular `Loan Lab`
   - Open [http://localhost:8080/loan](http://localhost:8080/loan)
   - Login with local IRIS credentials:
     - Username: `superuser`
     - Password: `SYS`
   - Use the built-in steps to:
     - check which production is active
     - switch to `Demo.Loan.FindRateProduction` automatically
     - test `Prime Rate`
     - test `Credit Rating`
     - submit a full application and inspect the aggregated bank responses

2. Self-contained CSP `Loan Lab`
   - Open [http://localhost:52774/csp/interop/DemoLoanLab.csp](http://localhost:52774/csp/interop/DemoLoanLab.csp)
   - Login to IRIS normally
   - Use the page buttons to run the same guided flow inside `/csp/interop`

3. Classic Loan form
   - Open [http://localhost:52774/csp/interop/DemoLoanForm.csp](http://localhost:52774/csp/interop/DemoLoanForm.csp)
   - Submit a request
   - Review the [Message Viewer](http://localhost:52774/csp/interop/EnsPortal.MessageViewer.zen)

#### 🔍 Steps:

1. Open the [Management Portal](http://localhost:52774/csp/sys/UtilHome.csp)
2. Login with:  
   - **Username:** `superuser`  
   - **Password:** `SYS`  
3. Navigate to:  
   **Interoperability > Namespace: `INTEROP` > List > Productions > `Demo.Loan.FindRateProduction` > Open**
4. Click **Start Production**
5. Explore the **Business Services**, **Processes**, and **Operations**
6. Use the green connector icons to inspect component interactions
7. Use the *Legend* to understand the meaning of component colors

#### 🧪 Test the Simulated External Operations

- Click `Demo.Loan.WebOperations`
- Go to **Actions > Test**
- Choose `Demo.Loan.Msg.PrimeRateRequest`
- Expected result: `PrimeRate = 3`
- Then choose `Demo.Loan.Msg.CreditRatingRequest`
- Suggested sample `TaxID`: `17`
- Expected result: `CreditRating = 70`
- Review the result in the **Visual Trace**
- Investigate the related classes and messages in **VS Code**

#### 🧾 Submit a Sample Loan Request From the Guided Labs

Suggested stable request:

- Amount: `18000`
- Name: `Paula Vega`
- TaxID: `19`
- Nationality: `USA`

Expected behavior:

- `PrimeRate` remains `3`
- `CreditRating` is calculated with the rule `(TaxID mod 10) * 10`
- The BPL evaluates multiple banks and returns the best approved offer
- The response includes record number, session id, duration, bank-by-bank replies, and links to Message Viewer / Visual Trace

#### 📁 Test the File-Based Loan Flow

The file service watches `/Practice/loan/in` and archives processed files to `/Practice/loan/inarchive`.

1. Create a file in `Practice/loan/in/`, for example `case1.application`
2. Use a single-line payload such as:

```text
10000:Daniel Sinpa:13:European
```

3. Start `Demo.Loan.FindRateProduction`
4. Review:
   - generated files in `Practice/loan/out`
   - the Message Viewer
   - the Visual Trace for the session

#### 🔧 Inspect the Business Process

- Open `Demo.Loan.FindRateDecisionProcessBPL` from the production config
- In the **Settings** tab, click the magnifier icon next to the *Class Name*
- Explore the graphical **BPL (Business Process Language)** definition
- When finished, **stop the production**

#### ⚠️ Local Demo Notes

- The TCP input service listens on port `1234`
- The TCP output operation tries to connect to port `4321`
- If nothing is listening on `4321`, `Demo.Loan.FindRateTCPOperation` will log timeout errors such as `ErrOutConnectExpired`
- This is expected unless you are explicitly testing the socket-based callback flow
- For normal workshop use, prefer Angular, CSP, Web, or File tests
- The sample SMTP server configured for `Demo.Loan.FindRateEMailOperation` is a placeholder and is not intended as a real local mail target

---

### 2. 📦 Handling Orders with DB Lookup & Web Service Call

This example processes incoming orders, enriches them with customer info from a MySQL database, and sends data to web services.

<img src="./img/scenario-order.png" width="900px"/>

#### 🗃️ Check the External Database

A MySQL database is already running in your Docker environment.

Run the following to inspect it:

```bash
docker exec -it mysql bash
mysql --host=localhost --user=testuser testdb -p  # Password: testpassword
```

Query example:

```sql
select * from customer;
```

> 🧠 You'll find sample customer data preloaded for testing.

#### ▶️ Start the Order Production

1. Navigate to:  
   **Interoperability > Namespace: `INTEROP` > List > Productions > `Demo.Order.Production` > Open**
2. Click **Start Production**

#### 📁 Process a Sample CSV File

1. In VS Code, copy files from `test/*.csv` into the `test/in/` folder
2. Watch the messages flow in the [Message Viewer](http://localhost:52774/csp/user/EnsPortal.MessageViewer.zen)

#### 🌐 Add a SOAP Web Service to Update Stock

Use the provided WSDL file to generate a web client:

1. In VS Code, open the **SOAP Wizard**
2. Use the following options:
   - **WSDL File:** `/install/StockSoapService.wdsl`
   - **Proxy Class Package:** `Demo.Order.WSC.Stock`
   - ✅ *Check "Create Business Operation"*
   - **Operation Class Package:** `Demo.Order.WSC.Stock.BO`
   - **Request/Response Package:** `Demo.Order.WSC.Stock.Msg`

Then:

3. In the production:
   - Add a new **Business Operation**
   - Set class to: `Demo.Order.WSC.Stock.BO.StockSoapServiceSoap`
   - Name it: `StockSoap WS Out`
4. Under Settings:
   - Add **SOAP Credentials**: `StockWS_User`
   - ✅ *Check "Enabled"*
5. Use **Actions > Test** to verify connectivity

#### 🔁 Update the Order Process to Use the Web Service

Now edit the Order Business Process to call the new SOAP operation.

```text
Edit the BPL to include a new step calling `StockSoap WS Out`
```

You can use the following image as a guide:

<img src="./img/order-process-stock.png" width="400" alt="Order Process with Stock Update" />


#### 🌐 Add a REST Order API

Now, you will add a new API to receive orders via REST.

1. In the production, add a new **Business Service**:
   - **Service Class**: `Demo.Order.BS.OrderAPI`
   - **Service Name**: `Order API In`
   - ✅ Check "Enable now"

2. Test the service using the included [Postman collection](./workshop-interop-intro.postman_collection.json)  
   **or** use `curl` from your terminal:

```bash
curl -X POST http://localhost:52774/order/api/order \
  -H "Content-Type: application/json" \
  -d '{
    "OrderPriority": "Not Specified",
    "Discount": "0",
    "UnitPrice": "205.99",
    "ShippingCost": "2.5",
    "CustomerID": "3",
    "ShipMode": "Express Air",
    "ProductCategory": "Technology",
    "ProductSubCategory": "Telephones and Communication",
    "ProductContainer": "Small Box",
    "ProductName": "V70",
    "OrderDate": "7/27/2011",
    "Quantity": "8",
    "Sales": "1446.67",
    "OrderID": "88523"
}'
```

> 💡 Check the [Message Viewer](http://localhost:52774/csp/user/EnsPortal.MessageViewer.zen) to see how the new REST request flows through the production.

3. After successfully testing the service using `curl`, try this [sample web app](http://localhost:8080).  
   It's a **simple Angular frontend** designed to illustrate how a web application can interact with **IRIS APIs**.

---

## 🧑‍🏫 Want to Learn More?

Check out the official [InterSystems Learning Portal](https://learning.intersystems.com) for more courses, videos, and certifications on interoperability and beyond.
