Class Demo.Order.BO.CustomerMySQLOperation Extends EnsLib.SQL.Operation.GenericOperation
{

/// Build a deterministic response object from the first query row.
Method ProcessQueryResponse(pResult As EnsLib.SQL.GatewayResultSet, Output pOutput As %RegisteredObject) As %Status
{
    set sc = $$$OK
    set pOutput = $$$NULLOREF

    try {
        if '$isobject(pResult) {
            set sc = $$$ERROR($$$EnsErrGeneral, "Customer MySQL Query did not return a result set")
        } else {
            set hasRow = pResult.Next(.sc)
            $$$ThrowOnError(sc)

            if 'hasRow {
                set sc = $$$ERROR($$$EnsErrGeneral, "Customer MySQL Query returned no rows")
            } else {
                set response = ##class(Demo.Order.Msg.CustomerInfo).%New()
                set response.CustomerID = pResult.Get("CustomerID")
                set response.CustomerName = pResult.Get("CustomerName")
                set response.CustomerSegment = pResult.Get("CustomerSegment")
                set pOutput = response

                set hasExtraRows = pResult.Next(.sc)
                $$$ThrowOnError(sc)
                if hasExtraRows {
                    $$$LOGWARNING("Customer MySQL Query returned multiple rows; only the first row will be used")
                }
            }
        }
    } catch ex {
        set sc = ex.AsStatus()
    }

    quit sc
}

}
