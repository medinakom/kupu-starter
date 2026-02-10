package id.my.mdn.kupu.app;

import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaModifier;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import id.my.mdn.kupu.core.base.view.FormPage;
import id.my.mdn.kupu.core.base.view.Page;
import id.my.mdn.kupu.core.base.view.annotation.View;
import id.my.mdn.kupu.core.base.view.widget.IValueList;
import jakarta.enterprise.context.ConversationScoped;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Named;
import java.io.File;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@AnalyzeClasses(packages = "id.my.mdn.kupu", importOptions = ImportOption.DoNotIncludeTests.class)
public class ArchitectureTest {

    @ArchTest
    public static final ArchRule page_subclasses_should_be_in_view_package = classes().that()
            .areAssignableTo(Page.class)
            .and().resideOutsideOfPackage("id.my.mdn.kupu.core..")
            .should().resideInAPackage("..view..")
            .allowEmptyShould(true)
            .because("Page subclasses represent Views and should reside in view packages");

    @ArchTest
    public static final ArchRule page_subclasses_should_be_named = classes().that().areAssignableTo(Page.class)
            .and().doNotHaveModifier(JavaModifier.ABSTRACT)
            .and().resideOutsideOfPackage("id.my.mdn.kupu.core..")
            .should().beAnnotatedWith(Named.class)
            .allowEmptyShould(true)
            .because("Page backing beans need to be CDI Named beans");

    @ArchTest
    public static final ArchRule page_subclasses_should_be_scoped = classes().that().areAssignableTo(Page.class)
            .and().doNotHaveModifier(JavaModifier.ABSTRACT)
            .and().areNotAssignableTo(FormPage.class)
            .and().resideOutsideOfPackage("id.my.mdn.kupu.core..")
            .should().beAnnotatedWith(jakarta.faces.view.ViewScoped.class)
            .orShould().beAnnotatedWith(ConversationScoped.class)
            .allowEmptyShould(true)
            .because("Standard Page backing beans must be either jakarta.faces.view.ViewScoped or ConversationScoped");

    @ArchTest
    public static final ArchRule form_page_subclasses_should_be_scoped = classes().that()
            .areAssignableTo(FormPage.class)
            .and().doNotHaveModifier(JavaModifier.ABSTRACT)
            .and().resideOutsideOfPackage("id.my.mdn.kupu.core..")
            .should().beAnnotatedWith(jakarta.faces.view.ViewScoped.class)
            .orShould().beAnnotatedWith(ConversationScoped.class)
            .orShould().beAnnotatedWith(Dependent.class)
            .allowEmptyShould(true)
            .because("FormPage backing beans can be jakarta.faces.view.ViewScoped, ConversationScoped, or Dependent");

    @ArchTest
    public static final ArchRule value_list_subclasses_should_be_dependent_scoped = classes().that()
            .areAssignableTo(IValueList.class)
            .and().doNotHaveModifier(JavaModifier.ABSTRACT)
            .and().resideOutsideOfPackage("id.my.mdn.kupu.core..")
            .should().beAnnotatedWith(Dependent.class)
            .allowEmptyShould(true)
            .because("Concrete IValueList implementations can only have dependent scope");

    @ArchTest
    public static final ArchRule page_subclasses_at_unusual_location_should_be_annotated_with_view = classes().that()
            .areAssignableTo(Page.class)
            .and().doNotHaveModifier(JavaModifier.ABSTRACT)
            // We only want to check classes that belong to this module's source
            .and().resideOutsideOfPackage("id.my.mdn.kupu.core..")
            .should(new ArchCondition<JavaClass>("be annotated with @View if at unusual location") {
                @Override
                public void check(JavaClass item, ConditionEvents events) {
                    if (item.isAnnotatedWith(View.class)) {
                        return;
                    }

                    String defaultPath = calculateDefaultPath(item.getFullName());
                    if (defaultPath == null) {
                        events.add(SimpleConditionEvent.violated(item, item.getFullName()
                                + " does not match the default Page naming convention and is not annotated with @View"));
                        return;
                    }

                    File resourceFile = new File("src/main/webapp" + defaultPath);
                    if (!resourceFile.exists()) {
                        String message = String.format(
                                "Class %s does not have @View annotation and its default view file %s does not exist in src/main/webapp",
                                item.getFullName(), defaultPath);
                        events.add(SimpleConditionEvent.violated(item, message));
                    }
                }

                private String calculateDefaultPath(String canonicalName) {
                    Pattern PAGE_PATTERN = Pattern.compile(
                            "(?:id\\.my\\.mdn\\.kupu)(?:(?<viewdir>(?:\\.[a-z]+)+)(?:(?<view>\\.[A-Z]\\w+)Page)?)?");
                    Matcher matcher = PAGE_PATTERN.matcher(canonicalName);
                    if (matcher.matches()) {
                        String viewdir = matcher.group("viewdir");
                        String view = matcher.group("view");
                        if (viewdir != null && view != null) {
                            return (viewdir + view).replaceAll("\\.", "/").toLowerCase() + ".xhtml";
                        }
                    }
                    return null;
                }
            })
            .allowEmptyShould(true);

}
