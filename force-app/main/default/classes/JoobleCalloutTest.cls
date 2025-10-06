@isTest
public class JoobleCalloutTest {
    @isTest
    static void testCallout() {
        Test.setMock(HttpCalloutMock.class, new JoobleMockGenerator());

        JoobleCalloutInvocable.Params p = new JoobleCalloutInvocable.Params();
        p.title = 'Salesforce Developer';
        p.location = 'Denver, CO';
        p.radius = 25;
        p.page = 1;
        p.resultsPerPage = 10;

        List<JoobleCalloutInvocable.Params> inputs = new List<JoobleCalloutInvocable.Params>{ p };

        Test.startTest();
        List<JoobleCalloutInvocable.Result> results = JoobleCalloutInvocable.run(inputs);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'There should be one result');
        System.assertEquals(200, results[0].statusCode, 'Status code should be 200');
        System.assertEquals('Success', results[0].message, 'Message should be Success');
        System.assert(results[0].parsedCount > 0, 'There should be at least one parsed job');
    }
}
