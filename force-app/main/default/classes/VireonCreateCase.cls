/**
 * Vireon virtual-human escalation - Create Case action.
 *
 * Opens a real Service Cloud Case when the Agentforce agent escalates a
 * customer to a "human" specialist. Assigns a human-looking specialist as the
 * Case owner (when such a user exists) and returns that specialist's name so
 * the agent's human_agent persona can speak as them. Falls back to the running
 * agent user as owner if no specialist user is provisioned.
 */
public with sharing class VireonCreateCase {
    // Display names used for the virtual-human specialist persona. If a User
    // with a matching name exists and is active, it is used as the Case owner.
    @TestVisible
    private static final List<String> SPECIALIST_NAMES = new List<String>{
        'Jordan Rivera', 'Priya Nair', 'Marcus Chen'
    };

    public class Request {
        @InvocableVariable(
            label='Subject'
            description='Short title for the case, summarizing the customer issue.'
            required=true
        )
        public String subject;

        @InvocableVariable(
            label='Issue Details'
            description='Summary of the conversation and the problem so far.'
            required=true
        )
        public String issueDetails;

        @InvocableVariable(
            label='Customer Name'
            description='The customer name if provided.'
        )
        public String customerName;

        @InvocableVariable(
            label='Customer Email'
            description='The customer email if provided.'
        )
        public String customerEmail;
    }

    public class Result {
        @InvocableVariable(label='Case Number')
        public String caseNumber;

        @InvocableVariable(label='Specialist Name')
        public String specialistName;

        @InvocableVariable(label='Case Id')
        public String caseId;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Vireon: Create Escalation Case'
        description='Creates a Service Cloud Case for the escalation and assigns a specialist owner.'
    )
    public static List<Result> createCase(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(processOne(req));
        }
        return results;
    }

    private static Result processOne(Request req) {
        Result res = new Result();
        try {
            User specialist = pickSpecialist();
            String name = (specialist != null)
                ? specialist.Name
                : SPECIALIST_NAMES[randomIndex(SPECIALIST_NAMES.size())];

            Case c = new Case(
                Subject = String.isBlank(req.subject) ? 'Vireon support request' : req.subject,
                Description = req.issueDetails,
                Origin = 'Chat',
                Status = 'Working',
                Priority = 'Medium',
                SuppliedName = req.customerName,
                SuppliedEmail = req.customerEmail
            );
            if (specialist != null) {
                c.OwnerId = specialist.Id;
            }
            try {
                insert c;
            } catch (DmlException de) {
                // Owner assignment to the specialist was not permitted; fall back
                // to a case owned by the running agent user so escalation still works.
                c.OwnerId = null;
                insert c;
            }

            Case created = [SELECT CaseNumber FROM Case WHERE Id = :c.Id LIMIT 1];

            insert new CaseComment(
                ParentId = c.Id,
                CommentBody = '[' + name + '] Case created from the Vireon web chat and assigned to me. '
                    + 'I\'ll take it from here.',
                IsPublished = true
            );

            res.caseId = c.Id;
            res.caseNumber = created.CaseNumber;
            res.specialistName = name;
            res.success = true;
            res.message = 'Case ' + created.CaseNumber + ' created.';
        } catch (Exception e) {
            res.success = false;
            res.message = 'Could not create case: ' + e.getMessage();
        }
        return res;
    }

    /**
     * Returns an active user whose name matches the specialist pool, or null if
     * none are provisioned (caller then falls back to a persona name only).
     */
    @TestVisible
    private static User pickSpecialist() {
        List<User> candidates = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true AND Name IN :SPECIALIST_NAMES
            LIMIT 10
        ];
        if (candidates.isEmpty()) {
            return null;
        }
        return candidates[randomIndex(candidates.size())];
    }

    // Crypto.getRandomInteger() can be negative; Math.mod of a negative value stays
    // negative, so guard the index to a valid, non-negative range.
    @TestVisible
    private static Integer randomIndex(Integer size) {
        if (size <= 1) {
            return 0;
        }
        return Math.mod(Math.abs(Crypto.getRandomInteger()), size);
    }
}
