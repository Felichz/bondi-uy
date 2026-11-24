- If I'm passing you `flutter run` logs and the logs don't have enough information about the bug I'm asking you to investigate, you must always add more prints as part of the investigation to capture the missing information in `flutter run`.

- If you fix a bug, you must check whether there is a test covering the functionality where that bug was. If there was a test, check why it wasn't catching that bug.

- Always remember to follow professional engineering best practices in your workflow. A professional programmer understands that the first problem is always to understand the problem and everything around it, to build a holistic view. The programmer reviews the code carefully and builds a clear mental map of the information flow, and when something doesn't fit, that is where they can debug better.
