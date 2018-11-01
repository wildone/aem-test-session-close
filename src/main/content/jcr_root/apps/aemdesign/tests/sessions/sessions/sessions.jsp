<%@page session="false" trimDirectiveWhitespaces="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@page import="org.apache.sling.api.resource.Resource,
                org.apache.sling.api.scripting.SlingScriptHelper,
                org.apache.sling.caconfig.resource.ConfigurationResourceResolver,
                javax.jcr.Session,
                javax.management.MBeanServerConnection,
                javax.management.ObjectName,
                javax.management.OperationsException,
                java.io.IOException,
                java.lang.management.ManagementFactory" %>
<%@ page import="java.util.*" %>
<%@ page import="java.util.stream.Collectors" %>
<%@ page import="org.apache.sling.api.resource.ResourceResolver" %>
<%@include file="/libs/granite/ui/global.jsp" %>
<%
    final HashMap<String, String> MBEAN_LABEL_MAP = new HashMap<String, String>();
    MBEAN_LABEL_MAP.put("SessionStatistics", "SessionStatistics");

    MBeanServerConnection server = ManagementFactory.getPlatformMBeanServer();
    Iterator<ObjectName> mbeanSessionStatistics = getMBeanIterator(server,"org.apache.jackrabbit.oak","SessionStatistics");

    ObjectName stats;

    HashMap<String, Integer> sessionCount = new HashMap<String, Integer>();

    Integer globalSessions = 1;

    while (mbeanSessionStatistics.hasNext()) {
        stats = mbeanSessionStatistics.next();

        String name = ObjectName.unquote(stats.getKeyProperty("name")).split("@")[0];
        Integer value = 1;

        if (sessionCount.containsKey(name)) {
            value = sessionCount.get(name) + 1;
        }

        sessionCount.put(name,value);
        globalSessions++;
    }

    String querystring = request.getQueryString();


    Boolean unsafesessions = false;
    if (querystring!=null) {
        unsafesessions = querystring.contains("unsafesessions");
    }

    org.apache.sling.api.scripting.SlingScriptHelper _sling = (org.apache.sling.api.scripting.SlingScriptHelper) pageContext.getAttribute("sling");

    String openStatus = "";
    if (_sling != null) {
        if (unsafesessions) {
            ResourceResolver unsafeAdminResourceResolver = openAdminResourceResolver(_sling);
            openStatus = "unsafe".concat(" - ").concat(unsafeAdminResourceResolver.toString());
            closeAdminResourceResolverUnsafe(unsafeAdminResourceResolver);
            unsafeAdminResourceResolver = null;
        } else {
            ResourceResolver safeAdminResourceResolver = openAdminResourceResolver(_sling);
            openStatus = "safe".concat(" - ").concat(safeAdminResourceResolver.toString());
            closeAdminResourceResolverSafe(safeAdminResourceResolver);
            safeAdminResourceResolver = null;
        }
    }

%>
<c:set var="sessionCount" value="<%= sessionCount %>"/>
<c:set var="globalSessions" value="<%= globalSessions %>"/>
<c:set var="querystring" value="<%= querystring %>"/>
<c:set var="unsafesessions" value="<%= unsafesessions %>"/>
<c:set var="openStatus" value="<%= openStatus %>"/>
<html>
<body>
<h1>Session Stats</h1>
<p>Users: ${fn:length(sessionCount)}</p>
<p>Total Sessions: ${globalSessions}</p>
<p>QueryString: ${querystring}</p>
<p>Admin Session Status: ${openStatus}</p>
<button onclick="location.reload();">RELOAD</button>
<c:if test="${!unsafesessions}">
<button onclick="location.href+='?unsafesessions=true'">Do Unsafe Session Open</button>
</c:if>
<c:if test="${unsafesessions}">
<button onclick="location.href=location.href.substring(0,location.href.indexOf('?'))">Do Safe Session Open</button>
</c:if>

<h1>Sessions List</h1>
<ul>
    <c:forEach items="${sessionCount}" var="entry" varStatus="entryStatus">
        <li>${entry}</li>
    </c:forEach>
</ul>
</body>
</html>

<%!
    private static final String CONFIG_BUCKET = "settings";

    private Collection<Resource> getConfigurations(Resource resource, String configName, SlingScriptHelper sling) {
        ConfigurationResourceResolver configurationResourceResolver = sling.getService(ConfigurationResourceResolver.class);
        Collection<Resource> chartConfigs = configurationResourceResolver.getResourceCollection(resource, CONFIG_BUCKET, configName);

        return chartConfigs;
    }

    private static ObjectName getSessionStatisticsMBean(MBeanServerConnection server)
            throws OperationsException, IOException {
        Set<ObjectName> names = server.queryNames(new ObjectName(
                "org.apache.jackrabbit.oak:type=SessionStatistics,*"), null);

        if (names.isEmpty()) {
            return null;
        }

        return names.iterator().next();
    }

    private static final String PACKAGE_PREFIX = "packagePrefix";
    private static final String DATA = "data";
    private static final String BEAN_NAME = "beanName";
    private static final String LEVELS ="levels";


    private ObjectName getMBean(MBeanServerConnection server,String prefix, String type)
            throws OperationsException, IOException {

        String beanObjectName =  prefix + ":type=" + type + ",*";
        return getMBean(server, beanObjectName);
    }

    private Iterator<ObjectName> getMBeanIterator(MBeanServerConnection server,String prefix, String type)
            throws OperationsException, IOException {

        String beanObjectName =  prefix + ":type=" + type + ",*";
        return getMBeanIterator(server, beanObjectName);
    }

    private ObjectName getMBean(MBeanServerConnection server, HashMap<String, ObjectName> beanCache, String prefix, String type)
            throws OperationsException, IOException {

        String beanObjectName =  prefix + ":type=" + type + ",*";
        if(beanCache.get(beanObjectName) == null) {
            beanCache.put(beanObjectName, getMBean(server, beanObjectName));
        }
        return beanCache.get(beanObjectName);
    }

    private ObjectName getMBean(MBeanServerConnection server, String beanObjectName)
            throws OperationsException, IOException {
        Set<ObjectName> names = server.queryNames(new ObjectName(beanObjectName), null);

        if (names.isEmpty()) {
            return null;
        }

        return names.iterator().next();
    }

    private Iterator<ObjectName> getMBeanIterator(MBeanServerConnection server, String beanObjectName)
            throws OperationsException, IOException {
            Set<ObjectName> names = server.queryNames(new ObjectName(beanObjectName), null);

        return names.iterator();
    }


    public org.apache.sling.api.resource.ResourceResolver openAdminResourceResolver(org.apache.sling.api.scripting.SlingScriptHelper _sling) {

        org.apache.sling.api.resource.ResourceResolver _adminResourceResolver = null;

        org.apache.sling.jcr.api.SlingRepository _slingRepository = _sling.getService(org.apache.sling.jcr.api.SlingRepository.class);
        org.apache.sling.api.resource.ResourceResolverFactory resolverFactory = _sling.getService(org.apache.sling.api.resource.ResourceResolverFactory.class);
        javax.jcr.Session session = null;
        try {
            session = _slingRepository.loginAdministrative(null);
            Map authInfo = new HashMap();
            authInfo.put(org.apache.sling.jcr.resource.api.JcrResourceConstants.AUTHENTICATION_INFO_SESSION, session);
            _adminResourceResolver = resolverFactory.getResourceResolver(authInfo);
        } catch (Exception ex) {
            // ex.printStackTrace();
        }

        return _adminResourceResolver;

    }


    public void closeAdminResourceResolverUnsafe(org.apache.sling.api.resource.ResourceResolver _adminResourceResolver) {

        if (_adminResourceResolver != null && _adminResourceResolver.isLive()) {

            _adminResourceResolver.close();
        }

    }


    public void closeAdminResourceResolverSafe(org.apache.sling.api.resource.ResourceResolver _adminResourceResolver) {

        if (_adminResourceResolver != null && _adminResourceResolver.isLive()) {

            javax.jcr.Session adminResourceSession = _adminResourceResolver.adaptTo(Session.class);
            if (adminResourceSession != null && adminResourceSession.isLive()) {
                adminResourceSession.logout();
            }

            _adminResourceResolver.close();
        }

    }
%>
