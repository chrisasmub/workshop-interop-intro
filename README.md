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

Status documented on **March 31, 2026** after bringing the project up locally with Docker.

### ✅ What Is Working

- `docker compose build` and `docker compose up -d` complete successfully
- IRIS, MySQL, and the Angular sample web app start correctly
- The IRIS portal is available at [http://localhost:52774/csp/sys/UtilHome.csp](http://localhost:52774/csp/sys/UtilHome.csp)
- The Order REST endpoint accepts requests at `POST /order/api/order`
- The local branch changes were pushed to GitHub and the repository is aligned with `origin/master`

### 🔧 Changes Applied During This Sprint

- Remapped IRIS ports from `1972/52773` to `11972/52774` to avoid collision with another local IRIS container
- Updated URLs in the README, Postman collection, web app environment files, and WSDL
- Added `Order API In` directly to `Demo.Order.Production` so the REST service is registered when the production starts
- Updated the `JavaGateway` host to use an External Language Server (`%Java Server`), which is required in this IRIS version
- Corrected `Demo.Order.Msg.CustomerInfo` so it extends `Ens.Response`
- Set `ParamSQLTypes` for the MySQL lookup to `SQL_INTEGER`

### ⚠️ Current Blocker

The Order flow is only **partially complete**.

What has been confirmed:

- REST requests return `201 Created`
- `Order API In` dispatches correctly to `Order Process`
- The Java Gateway now starts and stays alive
- The MySQL host `Customer MySQL Query` now starts and dequeues work

What is still failing:

- `EnsLib.SQL.Operation.GenericOperation` is still not returning a usable `Demo.Order.Msg.CustomerInfo` object to the BPL
- Because of that, `Order Process` still raises an alarm instead of continuing cleanly through the customer enrichment step
- For that reason, the browser-based end-to-end test was intentionally deferred until the backend lookup is stable

### Quick Reproduction

Start the production `Demo.Order.Production`, then test with:

```bash
curl -X POST http://localhost:52774/order/api/order \
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

Expected current behavior:

- The API responds with `201 Created`
- The message enters `Order Process`
- The flow still stops at the `Customer MySQL Query` enrichment stage

---

## 🗺️ Next Sprint Plan

Goal: finish debugging `EnsLib.SQL.Operation.GenericOperation` so the Order flow completes end to end.

### Sprint Focus

1. Verify exactly what object the SQL operation is returning when the query matches `CustomerID = 3`
2. Compare the configured `ResponseClass` with the actual result shape produced by `GenericOperation`
3. Inspect whether the operation needs additional settings beyond `ResponseClass` and `ParamSQLTypes`
4. Validate the BPL receives a real synchronous response and no longer falls back to the 30-second alarm path
5. Re-run the flow by:
   - REST `curl`
   - CSV file drop in `test/in`
   - browser test from `http://localhost:8080`

### Suggested Investigation Order

1. Inspect the response object generated by `Customer MySQL Query` for a known good `CustomerID`
2. Check whether `GenericOperation` expects extra result mapping configuration for JDBC result sets
3. If the built-in operation remains unreliable, replace it with a small custom Business Operation that:
   - opens the JDBC connection explicitly
   - executes the query
   - maps the first row into `Demo.Order.Msg.CustomerInfo`
   - returns a proper `Ens.Response`
4. After the DB enrichment works, continue with:
   - validating `Notification API Out`
   - testing the Angular flow
   - resuming the SOAP stock-update part of the workshop

### Definition Of Done For Next Sprint

- `POST /order/api/order` completes without alarms
- `Customer MySQL Query` returns a usable customer enrichment response
- `Notification API Out` is invoked after enrichment
- The sample web app can submit an order successfully against the fixed backend
- The README is updated again with the final end-to-end test result

---

## 📂 Examples

### 1. 💰 Loan Request Flow: Talk to Multiple Banks

In this scenario, the system receives a loan request and queries multiple banks to determine loan approval, then aggregates the responses.

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

#### 🧪 Test a Business Operation

- Click `Demo.Loan.WebOperations`
- Go to **Actions > Test**
- Choose `Demo.Loan.CreditRatingRequest` and provide some sample input
- Review the result in the **Visual Trace**
- Investigate the related classes and messages in **VS Code**

#### 🧾 Submit a Sample Loan Request

1. Open the [Loan Form Page](http://localhost:52774/csp/interop/DemoLoanForm.csp)
2. Submit a request with test data
3. View results in the [Message Viewer](http://localhost:52774/csp/interop/EnsPortal.MessageViewer.zen)
4. Review messages, traces, and how the system handled sync/async messaging and errors

#### 🔧 Inspect the Business Process

- Open `Demo.Loan.FindRateDecisionProcessBPL` from the production config
- In the **Settings** tab, click the magnifier icon next to the *Class Name*
- Explore the graphical **BPL (Business Process Language)** definition
- When finished, **stop the production**

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
