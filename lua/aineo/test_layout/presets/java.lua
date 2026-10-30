--- The test layouts of Java: Maven's and Gradle's `src/test/java` mirror,
--- the default, Failsafe's `IT` classes, and Gradle's integration-test
--- suite folder.

--- Surefire's default includes.
local SUREFIRE_DISCOVER =
  { '**/Test*.java', '**/*Test.java', '**/*Tests.java', '**/*TestCase.java' }

--- The unit test of a class, mirrored under `src/test/java`.
local MIRROR = {
  source = 'src/main/java/{path}/{name}.java',
  test = { 'src/test/java/{path}/{name}Test.java', 'src/test/java/{path}/{name}Tests.java' },
  kind = 'unit',
}

return {
  presets = {
    {
      id = 'java.junit.maven-mirror',
      framework = 'junit',
      doc = 'https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html',
      extensions = { 'java' },
      markers = { 'pom.xml', '**/pom.xml' },
      discover = SUREFIRE_DISCOVER,
      rules = { MIRROR },
    },
    {
      id = 'java.junit.maven-it',
      framework = 'junit',
      doc = 'https://maven.apache.org/surefire/maven-failsafe-plugin/examples/inclusion-exclusion.html',
      extensions = { 'java' },
      markers = { { file = '**/pom.xml', holds = 'maven-failsafe-plugin' } },
      discover = { '**/IT*.java', '**/*IT.java', '**/*ITCase.java' },
      rules = {
        {
          source = 'src/main/java/{path}/{name}.java',
          test = 'src/test/java/{path}/{name}IT.java',
          kind = 'integration',
        },
      },
    },
    {
      id = 'java.junit.gradle-mirror',
      framework = 'junit',
      doc = 'https://docs.gradle.org/current/userguide/organizing_gradle_projects.html',
      extensions = { 'java' },
      markers = { 'build.gradle', 'build.gradle.kts', '**/build.gradle', '**/build.gradle.kts' },
      discover = SUREFIRE_DISCOVER,
      rules = { MIRROR },
    },
    {
      id = 'java.junit.gradle-integrationtest',
      framework = 'junit',
      doc = 'https://docs.gradle.org/current/userguide/jvm_test_suite_plugin.html',
      extensions = { 'java' },
      markers = {
        { file = '**/build.gradle', holds = 'integrationTest' },
        { file = '**/build.gradle.kts', holds = 'integrationTest' },
      },
      discover = { 'src/integrationTest/java/**/*.java' },
      rules = { { folder = 'src/integrationTest/java/', kind = 'integration' } },
    },
  },
  defaults = { { id = 'java.junit.maven-mirror' } },
}
