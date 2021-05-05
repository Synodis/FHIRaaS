/// Run all test
/// do ##class(%UnitTest.Manager).DebugRunTestCase("","Test.FHIRAAS.API.impl",,)
Class Test.FHIRAAS.API.impl Extends %UnitTest.TestCase
{

Method OnBeforeAllTests() As %Status
{
   do ##class(FHIRAAS.API.impl).deleteTenant("TEST")
   set %response = ##class(%CSP.Response).%New() 
   Quit $$$OK
}

/// Run by <B>RunTest</B> immediately before each test method in the test class is run.<br>
/// <dl>
/// <dt><i>testname</i>
/// <dd>Name of the test to be run. Required. 
/// </dl> 
Method OnBeforeOneTest(testname As %String) As %Status
{
 Quit $$$OK
}

Method TestEmptygetTenants()
{
    set tExpect = []
    set tExpectToJson = tExpect.%ToJSON()

    set tResult = ##class(FHIRAAS.API.impl).getTenants()
    set tResultToJson = tResult.%ToJSON()

    do $$$AssertEquals(tResultToJson,tExpectToJson)
}

Method TestEmptygetTenant()
{
    set tExpect =   {
                        "errors": [
                            {
                                "code": 420,
                                "domain": "%ObjectErrors",
                                "error": "ERROR #420: Namespace TEST does not exist",
                                "id": "CPFNameDoesNotExist",
                                "params": [
                                    "Namespace",
                                    "TEST"
                                ]
                            }
                        ],
                        "summary": "ERROR #420: Namespace TEST does not exist"
                    }
  

    try {
        set tResult = ##class(FHIRAAS.API.impl).getTenant("TEST")
        //Should crash    
    } Catch ex {
        set sc = ##class(%CSP.REST).StatusToProxyObject(ex.AsStatus(),.tResult)

    }

    do $$$AssertEquals(tResult.summary,tExpect.summary)
}

Method TestShortputTenant()
{
    set tExpect =   {
                        "job_key": "MzAwNHx8MQ==",
                        "status": "running",
                        "type": "endpoint",
                        "name": "/v1/fhiraas/test/fhir/r4/endpoint"
                    }


    set tResult = ##class(FHIRAAS.API.impl).putTenant("TEST")

    do $$$AssertEquals(tResult.status,tExpect.status)
    do $$$AssertEquals(tResult.type,tExpect.type)
    do $$$AssertEquals(tResult.name,tExpect.name)
}

}
