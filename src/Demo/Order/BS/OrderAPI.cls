Class Demo.Order.BS.OrderAPI Extends (%CSP.REST, Ens.BusinessService)
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
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
