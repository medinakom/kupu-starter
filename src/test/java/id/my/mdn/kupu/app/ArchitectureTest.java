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

    @ArchTest
    public static final ArchRule entities_must_have_id_field = classes().that()
            .areAnnotatedWith(jakarta.persistence.Entity.class)
            .should(new ArchCondition<JavaClass>("have an 'id' field annotated with @Id or @EmbeddedId") {
                @Override
                public void check(JavaClass item, ConditionEvents events) {
                    boolean hasIdField = item.getAllFields().stream()
                            .anyMatch(field -> field.getName().equals("id") && 
                                    (field.isAnnotatedWith(jakarta.persistence.Id.class) || 
                                     field.isAnnotatedWith(jakarta.persistence.EmbeddedId.class)));
                    if (!hasIdField) {
                        events.add(SimpleConditionEvent.violated(item, item.getFullName() + " must have a field named 'id' annotated with @Id or @EmbeddedId"));
                    }
                }
            })
            .allowEmptyShould(true)
            .because("Kupu entities must use a standardized 'id' field for identity");

    @ArchTest
    public static final ArchRule entities_must_not_use_id_class = classes().that()
            .areAnnotatedWith(jakarta.persistence.Entity.class)
            .should().notBeAnnotatedWith(jakarta.persistence.IdClass.class)
            .allowEmptyShould(true)
            .because("Kupu uses @EmbeddedId for composite keys instead of @IdClass");

    @ArchTest
    public static final ArchRule entities_must_implement_standard_methods = classes().that()
            .areAnnotatedWith(jakarta.persistence.Entity.class)
            .and().doNotHaveModifier(JavaModifier.ABSTRACT)
            .should(new ArchCondition<JavaClass>("implement hashCode(), equals(Object), and toString()") {
                @Override
                public void check(JavaClass item, ConditionEvents events) {
                    boolean hasHashCode = item.getAllMethods().stream()
                            .anyMatch(m -> m.getName().equals("hashCode") && m.getRawParameterTypes().isEmpty()
                                    && !m.getOwner().getFullName().equals(Object.class.getName()));
                    boolean hasEquals = item.getAllMethods().stream()
                            .anyMatch(m -> m.getName().equals("equals") && m.getRawParameterTypes().size() == 1
                                    && m.getRawParameterTypes().get(0).isEquivalentTo(Object.class)
                                    && !m.getOwner().getFullName().equals(Object.class.getName()));
                    boolean hasToString = item.getAllMethods().stream()
                            .anyMatch(m -> m.getName().equals("toString") && m.getRawParameterTypes().isEmpty()
                                    && !m.getOwner().getFullName().equals(Object.class.getName()));

                    if (!hasHashCode)
                        events.add(
                                SimpleConditionEvent.violated(item, item.getFullName() + " must override hashCode()"));
                    if (!hasEquals)
                        events.add(SimpleConditionEvent.violated(item,
                                item.getFullName() + " must override equals(Object)"));
                    if (!hasToString)
                        events.add(
                                SimpleConditionEvent.violated(item, item.getFullName() + " must override toString()"));
                }
            })
            .allowEmptyShould(true)
            .because(
                    "Entities must implement hashCode, equals, and toString for correct collection handling and logging");

}
