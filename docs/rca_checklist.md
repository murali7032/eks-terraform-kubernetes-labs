1. Define the incident
Record the symptom, start/end time, affected service, environment, and known user impact.

2. Capture the exact error
Save the error message, request ID, timestamp with timezone, HTTP status, and relevant service or Pod names.

3. Build a timeline
Correlate application logs, Pod events, readiness changes, Service endpoints, and deployment changes around the same time.

4. Trace the request path
Follow the request from frontend to the failing backend. Verify the Service selector, endpoints, target port, and application listener.

5. Separate facts from hypotheses
Label each finding as confirmed, observed, suspected, or unknown. Do not turn correlation into causation.

6. Test the leading hypothesis
Choose the safest check that can distinguish between explanations before restarting, scaling, or changing configuration.

7. Restore and verify service
Confirm successful user-facing requests, healthy endpoints, and sustained recovery—not just a Running Pod.

8. Document corrective actions
Assign an owner, define a measurable success criterion, and record whether each action is proposed, in progress, or completed.

9. Close responsibly
Document residual uncertainty, evidence retained, monitoring, and follow-up work. An unresolved root cause can remain explicitly unresolved.