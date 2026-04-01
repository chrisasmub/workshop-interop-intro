Class Demo.Order.BS.OrderAPI Extends (%CSP.REST, Ens.BusinessService)
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Method="POST" Url = "/production/start" Call = "StartProduction" />
    <Route Method="GET" Url = "/production/status" Call = "ProductionStatus" />
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
        } elseif runningProduction '= "Demo.Order.Production" {
            set %response.Status = 409
            set payload = ##class(%DynamicObject).%New()
            do payload.%Set("error", "Another production is already running")
            do payload.%Set("runningProduction", runningProduction)
            do payload.%Set("requestedProduction", "Demo.Order.Production")
            write payload.%ToJSON()
            set handled = 1
        }

        if 'handled {
            do ..WriteProductionStatus()
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
    set productionName = ""
    set runningProduction = ""
    set state = ""

    set sc = ##class(Ens.Director).GetProductionStatus(.productionName, .state)
    $$$ThrowOnError(sc)

    set isRunning = ##class(Ens.Director).IsProductionRunning(.runningProduction)

    set payload = ##class(%DynamicObject).%New()
    do payload.%Set("requestedProduction", "Demo.Order.Production")
    do payload.%Set("activeProduction", productionName)
    do payload.%Set("runningProduction", $select(runningProduction="":"", 1:runningProduction))
    do payload.%Set("isRunning", +isRunning)
    do payload.%Set("stateCode", +state)
    do payload.%Set("stateLabel", ..ProductionStateLabel(state))
    do payload.%Set("matchesRequestedProduction", $select(productionName="Demo.Order.Production":1, 1:0))

    write payload.%ToJSON()
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

}
