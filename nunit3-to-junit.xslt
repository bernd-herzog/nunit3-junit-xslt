<?xml version="1.0" encoding="UTF-8"?>
<!--
  nunit3-to-junit.xslt

  Converts an NUnit3 result file (root <test-run>, written by nunit3-console)
  into the Apache Ant JUnit XML format (root <testsuites>, see junit.xsd).

  Result mapping

      NUnit3                        JUnit
      test-run                      testsuites
      test-suite[type=TestFixture]  testsuite        (one per leaf fixture)
      test-case (Failed)            failure          (Assert.Multiple: merged into one)
      test-case[label=Error]        error            (exception instead of assertion)
      test-case[label=Invalid]      error            (invalid test setup)
      test-case (Warning)           failure          (JUnit has no warning state)
      test-case (Skipped)           skipped
      output                        system-out       (suite level; JUnit has no per-test output)
      environment                   properties

  junit.xsd constraints this stylesheet must satisfy

  1. Every testsuite requires these children, in this exact order:
     properties, testcase*, system-out, system-err.
  2. Every testsuite requires the attributes:
     name, package, id, timestamp, hostname, tests, failures, errors, time.
     The timestamp must be ISO 8601 without timezone ("2026-11-25 18:53:21Z"
     becomes "2026-11-25T18:53:21").
  3. Each testcase allows at most one failure, one error and one skipped
     child, so several NUnit <failure> elements (Assert.Multiple) are
     merged into a single element.
  4. failure and error require a type attribute: the NUnit exception name.
  5. NUnit merges stdout, stderr and TestContext writes into a single
     <output> element; the format has no stderr channel, so system-err is
     always empty here.
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <!-- NOTE: deliberately no xsl:strip-space. The NUnit console runner feeds
       the stylesheet an already-loaded XmlNode through .NET's
       XslCompiledTransform, which refuses to strip whitespace from such
       documents ("Whitespace cannot be stripped from input documents that
       have already been loaded"). -->


  <!-- root: test-run -> testsuites

       Deliberately a relative pattern without a leading slash: the
       nunit3-console engine hands the result to XSLT as an XmlNode whose
       virtual document root IS the test-run element, while file-based
       processors (xsltproc, XslCompiledTransform on a file) present it as
       the root element of a document. A relative match serves both; a
       leading "/test-run" would silently produce empty output inside the
       console runner's transform= option. -->

  <xsl:template match="test-run">

    <testsuites>

      <!--
        One JUnit testsuite per LEAF fixture: the deepest TestFixture /
        ParameterizedFixture node that contains no further fixture.
        Parameterized fixtures nest (outer ParameterizedFixture, one inner
        TestFixture per argument set); counting the outer one as well
        would duplicate every test.
      -->

      <xsl:apply-templates
        select="//test-suite
                  [(@type = 'TestFixture' or @type = 'ParameterizedFixture')
                   and not(.//test-suite[@type = 'TestFixture'
                                      or @type = 'ParameterizedFixture'])]"
        mode="suite"/>

    </testsuites>

  </xsl:template>


  <!-- one leaf fixture -> one testsuite

       counting over the test-case leaves of the subtree:
       tests    = all test-cases
       failures = Failed without Error/Invalid label, plus Warning
       errors   = Failed with label Error or Invalid
       skipped  = Skipped -->

  <xsl:template match="test-suite" mode="suite">

    <testsuite>

      <xsl:attribute name="name">
        <xsl:value-of select="@name"/>
      </xsl:attribute>

      <!-- package = namespace part of the fixture full name -->
      <xsl:attribute name="package">
        <xsl:call-template name="namespace-part">
          <xsl:with-param name="path" select="@fullname"/>
        </xsl:call-template>
      </xsl:attribute>

      <!-- zero-based sequence number, as required by the schema -->
      <xsl:attribute name="id">
        <xsl:value-of select="position() - 1"/>
      </xsl:attribute>

      <xsl:attribute name="timestamp">
        <xsl:call-template name="iso-without-zone">
          <xsl:with-param name="s" select="@start-time"/>
        </xsl:call-template>
      </xsl:attribute>

      <xsl:attribute name="hostname">
        <xsl:choose>
          <xsl:when test="string //environment/@machine-name">
            <xsl:value-of select="//environment/@machine-name"/>
          </xsl:when>
          <xsl:otherwise>localhost</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>

      <xsl:attribute name="tests">
        <xsl:value-of select="count(.//test-case)"/>
      </xsl:attribute>

      <xsl:attribute name="failures">
        <xsl:value-of select="count(.//test-case[@result = 'Failed'
                                   and not(@label = 'Error')
                                   and not(@label = 'Invalid')])
                              + count(.//test-case[@result = 'Warning'])"/>
      </xsl:attribute>

      <xsl:attribute name="errors">
        <xsl:value-of select="count(.//test-case[@result = 'Failed']
                      [@label = 'Error' or @label = 'Invalid'])"/>
      </xsl:attribute>

      <!-- optional in the schema, but useful for CI readers -->
      <xsl:attribute name="skipped">
        <xsl:value-of select="count(.//test-case[@result = 'Skipped'])"/>
      </xsl:attribute>

      <xsl:attribute name="time">
        <xsl:choose>
          <xsl:when test="@duration"><xsl:value-of select="@duration"/></xsl:when>
          <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>


      <!-- required child 1: the NUnit run environment as JUnit properties -->

      <properties>
        <xsl:choose>
          <xsl:when test="//environment/@*">
            <xsl:for-each select="//environment/@*">
              <property name="{name()}" value="{.}"/>
            </xsl:for-each>
          </xsl:when>

          <xsl:otherwise>
            <property name="converted-by" value="nunit3-to-junit.xslt"/>
          </xsl:otherwise>
        </xsl:choose>
      </properties>


      <!-- required child 2: the test cases, in document order -->

      <xsl:apply-templates select=".//test-case" mode="case"/>


      <!-- required child 3: every <output> of the subtree, tagged with the
           name of the test or fixture that produced it -->

      <system-out>
        <xsl:for-each select=".//output">

          <xsl:text>[</xsl:text>
          <xsl:value-of select="parent::test-case/@name | parent::test-suite/@name"/>
          <xsl:text>]&#10;</xsl:text>

          <xsl:value-of select="."/>
          <xsl:text>&#10;</xsl:text>

        </xsl:for-each>
      </system-out>


      <!-- required child 4: always empty, see constraint 5 in the header -->

      <system-err/>

    </testsuite>

  </xsl:template>


  <!-- one NUnit test-case -> one JUnit testcase

       classname = full name of the owning leaf fixture, stripped of its
       ("argument") suffix. substring-before() yields '' when '(' is absent,
       so plain fixtures need the fullname fallback. -->

  <xsl:template match="test-case" mode="case">

    <xsl:variable name="fixture" select="ancestor::test-suite
                [(@type = 'TestFixture' or @type = 'ParameterizedFixture')
                 and not(.//test-suite[@type = 'TestFixture'
                                    or @type = 'ParameterizedFixture'])][1]
                /@fullname"/>

    <testcase name="{@name}">

      <xsl:attribute name="classname">
        <xsl:choose>
          <xsl:when test="contains($fixture, '(')">
            <xsl:value-of select="substring-before($fixture, '(')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$fixture"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>

      <!-- time is required; skipped and invalid cases often have none -->
      <xsl:attribute name="time">
        <xsl:choose>
          <xsl:when test="@time"><xsl:value-of select="@time"/></xsl:when>
          <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>


      <!-- 1) Skipped: [Ignore], [Explicit], [Platform(...)], Assert.Ignore.
            NUnit stores the reason as reason/message or reason/text. -->

      <xsl:if test="@result = 'Skipped'">

        <skipped>
          <xsl:attribute name="message">
            <xsl:choose>
              <xsl:when test="reason/message"><xsl:value-of select="reason/message"/></xsl:when>
              <xsl:when test="reason/text"><xsl:value-of select="reason/text"/></xsl:when>
              <xsl:otherwise><xsl:value-of select="@label"/></xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>

          <xsl:value-of select="reason/message | reason/text"/>
        </skipped>

      </xsl:if>


      <!-- 2) Error: exception in the test (label=Error) or invalid test
            arguments (label=Invalid). -->

      <xsl:if test="@result = 'Failed' and (@label = 'Error' or @label = 'Invalid')">

        <error message="{failure[1]/message}" type="{failure[1]/exception-name}">
          <xsl:call-template name="concatenate-failures">
            <xsl:with-param name="nodes" select="failure"/>
          </xsl:call-template>
        </error>

      </xsl:if>


      <!-- 3) Warning (Assert.Warn): reported as a failure, counted in the
            failures attribute. Text in reason/message, stack trace in
            assertions/assertion. -->

      <xsl:if test="@result = 'Warning'">

        <failure message="{reason/message}" type="NUnit.Framework.WarnException">
          <xsl:value-of select="reason/message"/>
          <xsl:text>&#10;</xsl:text>
          <xsl:value-of select="assertions/assertion/stack-trace"/>
        </failure>

      </xsl:if>


      <!-- 4) Regular assertion failure. Assert.Multiple produces several
            NUnit <failure> children; the schema allows one. -->

      <xsl:if test="@result = 'Failed'
                    and not(@label = 'Error')
                    and not(@label = 'Invalid')">

        <failure message="{failure[1]/message}" type="{failure[1]/exception-name}">
          <xsl:call-template name="concatenate-failures">
            <xsl:with-param name="nodes" select="failure"/>
          </xsl:call-template>
        </failure>

      </xsl:if>


      <!-- 5) Passed: an empty testcase element is JUnit's green state -->

    </testcase>

  </xsl:template>


  <!-- helpers -->


  <!-- merge several NUnit <failure> elements into one text block:
       message and stack trace per failure, separated by blank lines -->
  <xsl:template name="concatenate-failures">
    <xsl:param name="nodes"/>

    <xsl:for-each select="$nodes">

      <xsl:if test="position() &gt; 1">
        <xsl:text>&#10;&#10;</xsl:text>
      </xsl:if>

      <xsl:value-of select="message"/>
      <xsl:text>&#10;</xsl:text>
      <xsl:value-of select="stack-trace"/>

    </xsl:for-each>

  </xsl:template>


  <!-- normalize "YYYY-MM-DD HH:MM:SS[.fff][Z]" to
       "YYYY-MM-DDTHH:MM:SS"; missing stamp falls back to the epoch -->
  <xsl:template name="iso-without-zone">
    <xsl:param name="s"/>

    <xsl:choose>
      <xsl:when test="string-length($s) &gt;= 19">
        <xsl:value-of select="concat(substring($s, 1, 10), 'T', substring($s, 12, 8))"/>
      </xsl:when>

      <xsl:otherwise>1970-01-01T00:00:00</xsl:otherwise>
    </xsl:choose>

  </xsl:template>


  <!-- everything before the last dot of a dotted name:
       "A.B.C" -> "A.B", "A" -> "" ; recursive because XSLT 1.0 has
       no substring-before on the last occurrence -->
  <xsl:template name="namespace-part">
    <xsl:param name="path"/>

    <xsl:variable name="rest" select="substring-after($path, '.')"/>

    <xsl:if test="contains($path, '.')">

      <xsl:value-of select="substring-before($path, '.')"/>

      <xsl:if test="contains($rest, '.')">
        <xsl:text>.</xsl:text>
        <xsl:call-template name="namespace-part">
          <xsl:with-param name="path" select="$rest"/>
        </xsl:call-template>
      </xsl:if>

    </xsl:if>

  </xsl:template>

</xsl:stylesheet>
