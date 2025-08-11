	# Context -> Action/Intervention -> Outcome

Feature: Monitoring structural drift

  # Intent: Ensure that any structural change is detectable and results in stakeholder awareness

  Scenario Outline: Internal signal is generated and propagated on file system changes
    Given a file system is actively monitored
    When a <type> is <action>
    Then an internal signal is propagated
    And the responsible stakeholder is notified

    Examples:
      | TYPE      | ACTION  |
      | file      | removed |
      | directory | added   |
      | symlink   | removed |

