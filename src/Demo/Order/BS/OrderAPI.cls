Class Demo.Order.BS.OrderAPI Extends (%CSP.REST, Ens.BusinessService)
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Method="POST" Url = "/production/start" Call = "StartProduction" />
    <Route Method="GET" Url = "/production/status" Call = "ProductionStatus" />
    <Route Method="GET" Url = "/loan/production/status" Call = "LoanProductionStatus" />
    <Route Method="POST" Url = "/loan/production/prepare" Call = "PrepareLoanProduction" />
    <Route Method="POST" Url = "/loan/prime-rate" Call = "LoanPrimeRate" />
    <Route Method="POST" Url = "/loan/credit-rating" Call = "LoanCreditRating" />
    <Route Method="POST" Url = "/loan/application" Call = "LoanApplicationTest" />
    <Route Method="GET" Url = "/notifications/latest" Call = "LatestNotificationEcho" />
    <Route Method="GET" Url = "/orders" Call = "ListOrders" />
    <Route Method="POST" Url = "/order" Call = "NewOrder" />
</Routes>
}

/// Common config
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
    set %response.ContentType = "application/json"
    quit $$$OK
}

/// New Order
ClassMethod NewOrder()
{
    set ret = $$$OK

    try {
        // request body
        set body = %request.Content

        // instantiate Order from request body payload
        set msg = ##class(Demo.Order.Msg.Order).%JSONNew()
        $$$ThrowOnError(msg.%JSONImport(body))

        set validationSummary = ""
        set ret = ..ValidateOrderRequest(msg, .validationSummary)
        if $$$ISERR(ret) {
            set %response.Status = 400
            write "{""error"":""Invalid order request"",""summary"":"""_validationSummary_"""}"
            set ret = $$$OK
        } else {
            // instatiate interop business service and send to ingestion process
            $$$ThrowOnError(##class(Ens.Director).CreateBusinessService("Order API In", .service))
            $$$ThrowOnError(service.SendRequestAsync("Order Process", msg))
            
            // response status
            set %response.Status = "201"
            write {"result": "order created"}.%ToJSON()
        }

    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod ListOrders()
{
    set ret = $$$OK

    try {
        set stmt = ##class(%SQL.Statement).%New()
        set sql = "select top 20 h.ID as MessageId, h.SessionId, h.TimeCreated, o.OrderID, o.CustomerID, o.OrderPriority, o.ProductName, o.Sales "_
                  "from Ens.MessageHeader h join Demo_Order_Msg.Order o on h.MessageBodyId = o.ID "_
                  "where h.MessageBodyClassName = ? and h.SourceConfigName = ? "_
                  "order by h.ID desc"
        $$$ThrowOnError(stmt.%Prepare(sql))

        set rs = stmt.%Execute("Demo.Order.Msg.Order", "Order API In")
        set orders = ##class(%DynamicArray).%New()

        while rs.%Next() {
            set item = ##class(%DynamicObject).%New()
            do item.%Set("messageId", rs.%Get("MessageId"))
            do item.%Set("sessionId", rs.%Get("SessionId"))
            do item.%Set("timeCreated", rs.%Get("TimeCreated"))
            do item.%Set("orderId", rs.%Get("OrderID"))
            do item.%Set("customerId", rs.%Get("CustomerID"))
            do item.%Set("orderPriority", rs.%Get("OrderPriority"))
            do item.%Set("productName", rs.%Get("ProductName"))
            do item.%Set("sales", rs.%Get("Sales"))
            do orders.%Push(item)
        }

        write orders.%ToJSON()
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod ProductionStatus()
{
    set ret = $$$OK

    try {
        do ..WriteProductionStatus()
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod StartProduction()
{
    set ret = $$$OK

    try {
        set runningProduction = ""
        set isRunning = ##class(Ens.Director).IsProductionRunning(.runningProduction)
        set handled = 0

        if 'isRunning {
            set ret = ##class(Ens.Director).StartProduction("Demo.Order.Production")
            $$$ThrowOnError(ret)
            set %response.Status = 201
            write ..BuildProductionStatusPayload("Demo.Order.Production").%ToJSON()
        } elseif runningProduction '= "Demo.Order.Production" {
            set %response.Status = 409
            set payload = ##class(%DynamicObject).%New()
            do payload.%Set("error", "Another production is already running")
            do payload.%Set("runningProduction", runningProduction)
            do payload.%Set("requestedProduction", "Demo.Order.Production")
            write payload.%ToJSON()
            set handled = 1
        }

        if 'handled, isRunning, runningProduction = "Demo.Order.Production" {
            write ..BuildProductionStatusPayload("Demo.Order.Production").%ToJSON()
        }
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod LatestNotificationEcho()
{
    set ret = $$$OK

    try {
        do ..WriteNotificationEcho($get(%request.Data("sessionId",1)))
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod WriteProductionStatus()
{
    set payload = ..BuildProductionStatusPayload("Demo.Order.Production")
    write payload.%ToJSON()
}

ClassMethod LoanProductionStatus()
{
    set ret = $$$OK

    try {
        write ..BuildProductionStatusPayload("Demo.Loan.FindRateProduction").%ToJSON()
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod PrepareLoanProduction()
{
    set ret = $$$OK

    try {
        set payload = ..EnsureProduction("Demo.Loan.FindRateProduction", 1)

        if payload.%Get("action") '= "already-running" {
            set %response.Status = 201
        }

        write payload.%ToJSON()
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod LoanPrimeRate()
{
    set ret = $$$OK

    try {
        set payload = ##class(%DynamicObject).%New()
        do payload.%Set("step", "prime-rate")
        do payload.%Set("production", ..EnsureProduction("Demo.Loan.FindRateProduction", 1))
        do payload.%Set("sourceConfigName", "Demo.Loan.WebOperations")

        $$$ThrowOnError(##class(Ens.Director).CreateBusinessService("Demo.Loan.FindRateCSPService", .service))

        set request = ##class(Demo.Loan.Msg.PrimeRateRequest).%New()
        $$$ThrowOnError(service.SendRequestSync("Demo.Loan.WebOperations", request, .response, 10))

        do payload.%Set("responseClass", $classname(response))
        do payload.%Set("primeRate", response.PrimeRate)
        do payload.%Set("notes", ..BuildLoanNotesArray("Prime rate simulada desde Demo.Loan.WebOperations con USEWEBSERVICES=no.", "El valor esperado en esta demo es 3."))
        write payload.%ToJSON()
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod LoanCreditRating()
{
    set ret = $$$OK

    try {
        set body = ..ReadRequestBodyJson()
        set taxId = ..GetJsonString(body, "taxId", "17")

        set payload = ##class(%DynamicObject).%New()
        do payload.%Set("step", "credit-rating")
        do payload.%Set("production", ..EnsureProduction("Demo.Loan.FindRateProduction", 1))
        do payload.%Set("sourceConfigName", "Demo.Loan.WebOperations")
        do payload.%Set("taxId", taxId)

        $$$ThrowOnError(##class(Ens.Director).CreateBusinessService("Demo.Loan.FindRateCSPService", .service))

        set request = ##class(Demo.Loan.Msg.CreditRatingRequest).%New()
        set request.TaxID = taxId
        $$$ThrowOnError(service.SendRequestSync("Demo.Loan.WebOperations", request, .response, 10))

        do payload.%Set("responseClass", $classname(response))
        do payload.%Set("creditRating", response.CreditRating)
        do payload.%Set("derivedRule", "rating = (TaxID # 10) * 10")
        do payload.%Set("notes", ..BuildLoanNotesArray("La demo usa una regla determinística basada en el TaxID.", "Con TaxID="_taxId_" el rating calculado es "_response.CreditRating_"."))
        write payload.%ToJSON()
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod LoanApplicationTest()
{
    set ret = $$$OK

    try {
        set body = ..ReadRequestBodyJson()
        set amount = ..GetJsonString(body, "amount", "10000")
        set name = ..GetJsonString(body, "name", "Paula Vega")
        set taxId = ..GetJsonString(body, "taxId", "19")
        set nationality = ..GetJsonString(body, "nationality", "USA")

        set payload = ##class(%DynamicObject).%New()
        do payload.%Set("step", "application")
        do payload.%Set("processName", "Demo.Loan.FindRateDecisionProcessBPL")
        do payload.%Set("production", ..EnsureProduction("Demo.Loan.FindRateProduction", 1))

        set input = ##class(%DynamicObject).%New()
        do input.%Set("amount", amount)
        do input.%Set("name", name)
        do input.%Set("taxId", taxId)
        do input.%Set("nationality", nationality)
        do payload.%Set("input", input)

        $$$ThrowOnError(##class(Ens.Director).CreateBusinessService("Demo.Loan.FindRateCSPService", .service))

        set application = ##class(Demo.Loan.Msg.Application).%New()
        set application.Amount = amount
        set application.Name = name
        set application.TaxID = taxId
        set application.Nationality = nationality
        set application.BusinessOperationType = "web"
        set application.Destination = ""

        set recordNumber = application.RecordNumber()
        do payload.%Set("recordNumber", +recordNumber)
        do payload.%Set("receiptText", application.GetRecordNumberText())

        set startedAt = $horolog
        $$$ThrowOnError(service.SendRequestSync("Demo.Loan.FindRateDecisionProcessBPL", application, .approval, 20))
        set finishedAt = $horolog

        do ..FindMessageHeaderByBody("Demo.Loan.Msg.Application", recordNumber, .headerId, .sessionId, .timeCreated)
        set bankReplies = ..BuildLoanBankReplyArray(sessionId)
        set finalApproval = ..LoanApprovalToDynamic(approval)
        if finalApproval.%Get("bankName") = "" {
            set finalApproval = ..BuildLoanApprovalFromBankReplies(bankReplies)
        }

        do payload.%Set("approval", finalApproval)
        do payload.%Set("durationSeconds", ..ElapsedSeconds(startedAt, finishedAt))

        set session = ##class(%DynamicObject).%New()
        do session.%Set("messageHeaderId", +headerId)
        do session.%Set("sessionId", +sessionId)
        do session.%Set("timeCreated", timeCreated)
        do session.%Set("messageViewerLink", "http://localhost:52774/csp/interop/EnsPortal.MessageViewer.zen?$NAMESPACE=INTEROP")
        do session.%Set("visualTraceLink", $select(+sessionId>0:"http://localhost:52774/csp/interop/EnsPortal.VisualTrace.zen?SESSIONID="_(+sessionId), 1:""))
        do payload.%Set("session", session)

        do payload.%Set("bankReplies", bankReplies)
        do payload.%Set("trace", ..BuildLoanTraceArray(sessionId))
        do payload.%Set("notes", ..BuildLoanNotesArray("La solicitud se ejecuta por el BPL real para mantener el flujo autocontenido.", "El resumen incluye respuestas de bancos y trazas de la sesión."))

        write payload.%ToJSON()
    } catch ex {
        set ret = ex.AsStatus()
        set %response.Status = 500
    }

    quit ret
}

ClassMethod WriteNotificationEcho(pSessionId As %String = "")
{
    set stmt = ##class(%SQL.Statement).%New()
    set sql = "select top 20 ID, SessionId, TimeLogged, Text "_
              "from Ens_Util.Log where ConfigName = ?"
    set hasSessionFilter = ($zstrip($get(pSessionId), "<>W") '= "")

    if hasSessionFilter {
        set sql = sql_" and SessionId = ?"
    }

    set sql = sql_" order by ID desc"
    $$$ThrowOnError(stmt.%Prepare(sql))

    if hasSessionFilter {
        set rs = stmt.%Execute("Notification API Out", +pSessionId)
    } else {
        set rs = stmt.%Execute("Notification API Out")
    }

    set requestText = ""
    set requestLoggedAt = ""
    set responseText = ""
    set responseLoggedAt = ""
    set sessionId = ""

    while rs.%Next() {
        set text = $property(rs, "Text")

        if sessionId = "" {
            set sessionId = +$property(rs, "SessionId")
        }

        if responseText = "", $extract(text,1,9) = "response=" {
            set responseText = $extract(text,10,*)
            set responseLoggedAt = $property(rs, "TimeLogged")
        } elseif requestText = "", $extract($zstrip(text, "<>W"),1,1) = "{" {
            set requestText = text
            set requestLoggedAt = $property(rs, "TimeLogged")
        }

        if (requestText '= "") && (responseText '= "") {
            quit
        }
    }

    if sessionId = "" {
        set %response.Status = 404
        set payload = ##class(%DynamicObject).%New()
        do payload.%Set("error", "Notification echo not found")
        do payload.%Set("summary", "No log entries were found for Notification API Out")
        write payload.%ToJSON()
        quit
    }

    if responseText = "" {
        set %response.Status = 202
    }

    set payload = ##class(%DynamicObject).%New()
    do payload.%Set("sessionId", +sessionId)
    do payload.%Set("sourceConfigName", "Notification API Out")
    do payload.%Set("requestFound", +(requestText '= ""))
    do payload.%Set("responseFound", +(responseText '= ""))
    do payload.%Set("requestLoggedAt", requestLoggedAt)
    do payload.%Set("responseLoggedAt", responseLoggedAt)
    do payload.%Set("requestRaw", requestText)
    do payload.%Set("responseRaw", responseText)

    if requestText '= "" {
        try {
            set requestJson = {}.%FromJSON(requestText)
            do payload.%Set("requestJson", requestJson)
        } catch ex {
        }
    }

    if responseText '= "" {
        try {
            set responseJson = {}.%FromJSON(responseText)
            do payload.%Set("responseJson", responseJson)

            if responseJson.%IsDefined("origin") {
                do payload.%Set("httpbinOrigin", responseJson.%Get("origin"))
            }

            if responseJson.%IsDefined("url") {
                do payload.%Set("httpbinUrl", responseJson.%Get("url"))
            }
        } catch ex {
        }
    }

    write payload.%ToJSON()
}

ClassMethod ProductionStateLabel(pState As %Integer) As %String
{
    quit $case(+pState,
        1: "running",
        2: "stopped",
        : "unknown"
    )
}

ClassMethod ValidateOrderRequest(pMsg As Demo.Order.Msg.Order, Output pSummary As %String = "") As %Status
{
    set pSummary = ""

    do ..AppendMissingField(.pSummary, "OrderPriority", pMsg.OrderPriority)
    do ..AppendMissingField(.pSummary, "Discount", pMsg.Discount)
    do ..AppendMissingField(.pSummary, "UnitPrice", pMsg.UnitPrice)
    do ..AppendMissingField(.pSummary, "ShippingCost", pMsg.ShippingCost)
    do ..AppendMissingField(.pSummary, "CustomerID", pMsg.CustomerID)
    do ..AppendMissingField(.pSummary, "ShipMode", pMsg.ShipMode)
    do ..AppendMissingField(.pSummary, "ProductCategory", pMsg.ProductCategory)
    do ..AppendMissingField(.pSummary, "ProductSubCategory", pMsg.ProductSubCategory)
    do ..AppendMissingField(.pSummary, "ProductContainer", pMsg.ProductContainer)
    do ..AppendMissingField(.pSummary, "ProductName", pMsg.ProductName)
    do ..AppendMissingField(.pSummary, "OrderDate", pMsg.OrderDate)
    do ..AppendMissingField(.pSummary, "Quantity", pMsg.Quantity)
    do ..AppendMissingField(.pSummary, "Sales", pMsg.Sales)
    do ..AppendMissingField(.pSummary, "OrderID", pMsg.OrderID)

    if pSummary'="" {
        set pSummary = "Missing required fields: "_pSummary
        quit $$$ERROR($$$EnsErrGeneral, pSummary)
    }

    quit $$$OK
}

ClassMethod AppendMissingField(ByRef pSummary As %String, pField As %String, pValue As %String = "")
{
    if $zstrip($get(pValue), "<>W") = "" {
        set pSummary = $select(pSummary="":pField, 1:pSummary_", "_pField)
    }
}

ClassMethod BuildProductionStatusPayload(pRequestedProduction As %String) As %DynamicObject
{
    set productionName = ""
    set runningProduction = ""
    set state = ""

    set sc = ##class(Ens.Director).GetProductionStatus(.productionName, .state)
    $$$ThrowOnError(sc)

    set isRunning = ##class(Ens.Director).IsProductionRunning(.runningProduction)

    set payload = ##class(%DynamicObject).%New()
    do payload.%Set("requestedProduction", pRequestedProduction)
    do payload.%Set("activeProduction", productionName)
    do payload.%Set("runningProduction", $select(runningProduction="":"", 1:runningProduction))
    do payload.%Set("isRunning", +isRunning)
    do payload.%Set("stateCode", +state)
    do payload.%Set("stateLabel", ..ProductionStateLabel(state))
    do payload.%Set("matchesRequestedProduction", $select(productionName=pRequestedProduction:1, 1:0))

    quit payload
}

ClassMethod EnsureProduction(pRequestedProduction As %String, pAllowStop As %Boolean = 0) As %DynamicObject
{
    set payload = ##class(%DynamicObject).%New()
    set payload = ..BuildProductionStatusPayload(pRequestedProduction)
    do payload.%Set("action", "already-running")

    if '(payload.%Get("isRunning")) {
        set sc = ##class(Ens.Director).StartProduction(pRequestedProduction)
        $$$ThrowOnError(sc)
        hang 1
        set payload = ..BuildProductionStatusPayload(pRequestedProduction)
        do payload.%Set("action", "started")
        quit payload
    }

    if payload.%Get("runningProduction") '= pRequestedProduction {
        if 'pAllowStop {
            set sc = $$$ERROR($$$EnsErrGeneral, "Another production is already running")
            $$$ThrowOnError(sc)
        }

        do payload.%Set("previousProduction", payload.%Get("runningProduction"))
        set sc = ##class(Ens.Director).StopProduction(15, 0)
        $$$ThrowOnError(sc)
        set sc = ##class(Ens.Director).StartProduction(pRequestedProduction)
        $$$ThrowOnError(sc)
        hang 1
        set payload = ..BuildProductionStatusPayload(pRequestedProduction)
        do payload.%Set("action", "switched")
        quit payload
    }

    quit payload
}

ClassMethod ReadRequestBodyText() As %String
{
    set stream = %request.Content
    set text = ""

    if '$isobject(stream) {
        quit text
    }

    do stream.Rewind()

    while 'stream.AtEnd {
        set text = text_stream.Read(32000)
    }

    quit text
}

ClassMethod ReadRequestBodyJson() As %DynamicObject
{
    set text = ..ReadRequestBodyText()
    set payload = ##class(%DynamicObject).%New()

    if $zstrip(text, "<>W") = "" {
        quit payload
    }

    quit {}.%FromJSON(text)
}

ClassMethod GetJsonString(pBody As %DynamicObject, pKey As %String, pDefault As %String = "") As %String
{
    set value = pDefault

    if '$isobject(pBody) {
        quit pDefault
    }

    if 'pBody.%IsDefined(pKey) {
        quit pDefault
    }

    set value = pBody.%Get(pKey)
    quit $select(value="":pDefault, 1:value)
}

ClassMethod LoanApprovalToDynamic(pApproval As Demo.Loan.Msg.Approval) As %DynamicObject
{
    set payload = ##class(%DynamicObject).%New()

    if '$isobject(pApproval) {
        do payload.%Set("bankName", "")
        do payload.%Set("isApproved", 0)
        do payload.%Set("interestRate", "")
        do payload.%Set("text", "")
        quit payload
    }

    do payload.%Set("bankName", pApproval.BankName)
    do payload.%Set("isApproved", +pApproval.IsApproved)
    do payload.%Set("interestRate", pApproval.InterestRate)
    do payload.%Set("text", pApproval.GetText())

    quit payload
}

ClassMethod FindMessageHeaderByBody(pBodyClassName As %String, pBodyId As %Integer, Output pHeaderId As %Integer = 0, Output pSessionId As %Integer = 0, Output pTimeCreated As %String = "")
{
    set pHeaderId = 0
    set pSessionId = 0
    set pTimeCreated = ""

    set stmt = ##class(%SQL.Statement).%New()
    set sql = "select top 1 ID as HeaderId, SessionId, TimeCreated "_
              "from Ens.MessageHeader "_
              "where MessageBodyClassName = ? and MessageBodyId = ? "_
              "order by ID desc"
    $$$ThrowOnError(stmt.%Prepare(sql))

    set rs = stmt.%Execute(pBodyClassName, +pBodyId)

    if rs.%Next() {
        set pHeaderId = +rs.%Get("HeaderId")
        set pSessionId = +rs.%Get("SessionId")
        set pTimeCreated = rs.%Get("TimeCreated")
    }
}

ClassMethod BuildLoanBankReplyArray(pSessionId As %Integer) As %DynamicArray
{
    set items = ##class(%DynamicArray).%New()

    if +$get(pSessionId)'>0 {
        quit items
    }

    set stmt = ##class(%SQL.Statement).%New()
    set sql = "select h.ID as MessageId, h.SessionId, h.TimeCreated, h.SourceConfigName, h.TargetConfigName, "_
              "a.BankName, a.IsApproved, a.InterestRate "_
              "from Ens.MessageHeader h "_
              "join Demo_Loan_Msg.Approval a on h.MessageBodyId = a.ID "_
              "where h.SessionId = ? and h.MessageBodyClassName = ? and h.SourceConfigName %STARTSWITH ? "_
              "order by h.ID"
    $$$ThrowOnError(stmt.%Prepare(sql))

    set rs = stmt.%Execute(+pSessionId, "Demo.Loan.Msg.Approval", "Demo.Loan.Bank")

    while rs.%Next() {
        set item = ##class(%DynamicObject).%New()
        do item.%Set("messageId", +rs.%Get("MessageId"))
        do item.%Set("sessionId", +rs.%Get("SessionId"))
        do item.%Set("timeCreated", rs.%Get("TimeCreated"))
        do item.%Set("sourceConfigName", rs.%Get("SourceConfigName"))
        do item.%Set("targetConfigName", rs.%Get("TargetConfigName"))
        do item.%Set("bankName", rs.%Get("BankName"))
        do item.%Set("isApproved", +rs.%Get("IsApproved"))
        do item.%Set("interestRate", rs.%Get("InterestRate"))
        do items.%Push(item)
    }

    quit items
}

ClassMethod BuildLoanTraceArray(pSessionId As %Integer) As %DynamicArray
{
    set items = ##class(%DynamicArray).%New()

    if +$get(pSessionId)'>0 {
        quit items
    }

    set stmt = ##class(%SQL.Statement).%New()
    set sql = "select top 40 TimeLogged, ConfigName, Text "_
              "from Ens_Util.Log "_
              "where SessionId = ? and (ConfigName %STARTSWITH ? or ConfigName = ?) "_
              "order by ID"
    $$$ThrowOnError(stmt.%Prepare(sql))

    set rs = stmt.%Execute(+pSessionId, "Demo.Loan.", "My Terminal Output")

    while rs.%Next() {
        set item = ##class(%DynamicObject).%New()
        do item.%Set("timeLogged", rs.%Get("TimeLogged"))
        do item.%Set("configName", rs.%Get("ConfigName"))
        do item.%Set("text", rs.%Get("Text"))
        do items.%Push(item)
    }

    quit items
}

ClassMethod BuildLoanApprovalFromBankReplies(pBankReplies As %DynamicArray) As %DynamicObject
{
    set approval = ##class(%DynamicObject).%New()
    do approval.%Set("bankName", "")
    do approval.%Set("isApproved", 0)
    do approval.%Set("interestRate", "")
    do approval.%Set("text", "")

    if '$isobject(pBankReplies) {
        quit approval
    }

    for i=0:1:(pBankReplies.%Size()-1) {
        set item = pBankReplies.%Get(i)
        continue:'$isobject(item)

        if approval.%Get("bankName") = "" {
            do approval.%Set("bankName", item.%Get("bankName"))
        }

        if 'item.%Get("isApproved") {
            continue
        }

        if (approval.%Get("isApproved") = 0) || (+item.%Get("interestRate") < +approval.%Get("interestRate")) {
            do approval.%Set("bankName", item.%Get("bankName"))
            do approval.%Set("isApproved", 1)
            do approval.%Set("interestRate", item.%Get("interestRate"))
        }
    }

    if approval.%Get("isApproved") {
        do approval.%Set("text", "Best available offer: "_approval.%Get("bankName")_" at "_approval.%Get("interestRate")_"%.")
    } else {
        do approval.%Set("text", "No bank approved the application within the observed replies.")
    }

    quit approval
}

ClassMethod BuildLoanNotesArray(pNote1 As %String = "", pNote2 As %String = "") As %DynamicArray
{
    set notes = ##class(%DynamicArray).%New()

    if $zstrip($get(pNote1), "<>W") '= "" {
        do notes.%Push(pNote1)
    }

    if $zstrip($get(pNote2), "<>W") '= "" {
        do notes.%Push(pNote2)
    }

    quit notes
}

ClassMethod ElapsedSeconds(pStarted As %String, pFinished As %String) As %Numeric
{
    if ($piece($get(pStarted), ",", 1) = "") || ($piece($get(pFinished), ",", 1) = "") {
        quit ""
    }

    quit (($piece(pFinished, ",", 1) * 86400) + $piece(pFinished, ",", 2)) - (($piece(pStarted, ",", 1) * 86400) + $piece(pStarted, ",", 2))
}

}
