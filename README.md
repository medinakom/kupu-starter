# Kupu Application Generated Project

This project was generated using the Kupu Starter Skeleton. It follows strict architectural standards to ensure maintainability and consistency.

## 🏛️ Architectural Standards

This application enforces the following rules via **ArchUnit**. These rules are automatically verified during the build process (`mvn test`).

### 1. View Layer Packaging
- All `Page` subclasses must reside in a `..view..` package.
- This keeps UI backing beans separate from business logic.

### 2. CDI Naming & Scoping
- **Standard Pages**: Must be `@Named` and annotated with either `jakarta.faces.view.ViewScoped` or `jakarta.enterprise.context.ConversationScoped`.
- **Form Pages**: Can additionally be `@Dependent`.
- **Value Lists**: Concrete `IValueList` implementations must be `@Dependent`.

### 3. Automated View Resolution
- The framework uses a naming convention: `ClassNamePage` -> `classname.xhtml`.
- If a page is located at an unusual path, it **must** be annotated with `@View`.
- The architecture test verifies that the referenced XHTML file actually exists in `src/main/webapp`.

## 🛠️ Development Tools

- `./create-module.sh`: Generate a new module structure.
- `./create-entity-view.sh`: Generate CRUD views for an entity.
- `./create-page.sh`: Generate a new JSF page and backing bean.
- `./create-config-jar.sh`: Generate a configuration JAR (datasource, environment).
- `./generate-persistence.sh`: Automatically update `persistence.xml`.

## ✅ Verifying Compliance

Run the following command to ensure the project still follows the architectural rules:

```bash
mvn test -Dtest=ArchitectureTest
```

Failure to follow these rules will break the build, preventing architectural erosion.

---


*Powered by Kupu Framework*

## 📚 Documentation

For detailed instructions on using the automation scripts (creating modules, pages, entities, roles, etc.), please refer to the **[Scripts Manual](SCRIPTS.md)**.

