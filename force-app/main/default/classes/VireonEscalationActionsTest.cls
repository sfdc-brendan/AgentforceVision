@isTest
private class VireonEscalationActionsTest {
    @isTest
    static void createsCommentsAndResolvesCase() {
        VireonCreateCase.Request create = new VireonCreateCase.Request();
        create.subject = 'Router keeps blinking red';
        create.issueDetails = 'Customer reports the Vireon Hub router shows a solid red light.';
        create.customerName = 'Alex Customer';
        create.customerEmail = 'alex@example.com';

        Test.startTest();
        List<VireonCreateCase.Result> created =
            VireonCreateCase.createCase(new List<VireonCreateCase.Request>{ create });

        System.assertEquals(1, created.size(), 'One result expected');
        VireonCreateCase.Result cr = created[0];
        System.assertEquals(true, cr.success, 'Case should be created: ' + cr.message);
        System.assertNotEquals(null, cr.caseId, 'Case id expected');
        System.assertNotEquals(null, cr.caseNumber, 'Case number expected');
        System.assert(String.isNotBlank(cr.specialistName), 'Specialist name expected');

        VireonAddCaseComment.Request comment = new VireonAddCaseComment.Request();
        comment.caseId = cr.caseId;
        comment.commentBody = 'Walked the customer through a power cycle.';
        comment.authorName = cr.specialistName;
        List<VireonAddCaseComment.Result> commented =
            VireonAddCaseComment.addComment(new List<VireonAddCaseComment.Request>{ comment });
        System.assertEquals(true, commented[0].success, commented[0].message);

        VireonResolveCase.Request resolve = new VireonResolveCase.Request();
        resolve.caseId = cr.caseId;
        resolve.resolutionSummary = 'Power cycle cleared the fault; router back online.';
        resolve.authorName = cr.specialistName;
        List<VireonResolveCase.Result> resolved =
            VireonResolveCase.resolveCase(new List<VireonResolveCase.Request>{ resolve });
        Test.stopTest();

        System.assertEquals(true, resolved[0].success, resolved[0].message);

        Case after = [SELECT Status FROM Case WHERE Id = :cr.caseId LIMIT 1];
        System.assertEquals('Closed', after.Status, 'Case should be closed');

        Integer comments = [SELECT COUNT() FROM CaseComment WHERE ParentId = :cr.caseId];
        System.assert(comments >= 3, 'Expected creation, work, and resolution comments');
    }

    @isTest
    static void handlesMissingInputsGracefully() {
        VireonAddCaseComment.Request bad = new VireonAddCaseComment.Request();
        List<VireonAddCaseComment.Result> r =
            VireonAddCaseComment.addComment(new List<VireonAddCaseComment.Request>{ bad });
        System.assertEquals(false, r[0].success, 'Blank input should fail gracefully');

        VireonResolveCase.Request badResolve = new VireonResolveCase.Request();
        List<VireonResolveCase.Result> rr =
            VireonResolveCase.resolveCase(new List<VireonResolveCase.Request>{ badResolve });
        System.assertEquals(false, rr[0].success, 'Blank input should fail gracefully');
    }
}
