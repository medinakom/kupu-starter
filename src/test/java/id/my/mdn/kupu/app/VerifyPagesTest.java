package id.my.mdn.kupu.app;

import id.my.mdn.kupu.core.base.util.ModuleUtil;
import id.my.mdn.kupu.core.base.view.Page;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.reflections.Reflections;

import java.io.File;
import java.net.URL;
import java.util.Set;
import java.util.stream.Collectors;

public class VerifyPagesTest {

    @Test
    public void verifyAllPagesHaveViews() {
        Reflections reflections = new Reflections("id.my.mdn.kupu");
        Set<Class<? extends Page>> pages = reflections.getSubTypesOf(Page.class);

        StringBuilder missingViews = new StringBuilder();

        for (Class<? extends Page> pageClass : pages) {
            // Skip abstract classes
            if (java.lang.reflect.Modifier.isAbstract(pageClass.getModifiers())) {
                continue;
            }

            String viewPath = ModuleUtil.getViewPath(pageClass);

            if (viewPath == null) {
                // If regex doesn't match, that's also a maintainability issue, but maybe
                // intended for internal pages?
                // For now, let's assume all concrete pages must match.
                missingViews.append("Page class ").append(pageClass.getName())
                        .append(" does not match the naming convention defined in ModuleUtil.\n");
                continue;
            }

            // Check 1: Is it in the classpath (Core JARs)?
            URL resource = getClass().getResource("/META-INF/resources" + viewPath);
            if (resource != null) {
                continue;
            }

            // Check 2: Is it in the local webapp source (App WAR)?
            File webappFile = new File("src/main/webapp" + viewPath);
            if (webappFile.exists()) {
                continue;
            }

            // Failure
            missingViews.append("View not found for ").append(pageClass.getName())
                    .append(". Expected at: ").append(viewPath).append("\n");
        }

        if (missingViews.length() > 0) {
            Assertions.fail("Some pages are missing their view files:\n" + missingViews.toString());
        }
    }
}
